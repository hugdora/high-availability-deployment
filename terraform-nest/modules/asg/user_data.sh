#!/bin/bash
set -xe
exec > /tmp/nest-bootstrap.log 2>&1

S3_LOG_BUCKET="${S3_BUCKET}"
AWS_REGION="${AWS_REGION}"
SECRET_NAME="${SECRET_NAME}"
DB_HOST="${DB_HOST}"
APP_URL="${APP_URL}"

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
S3_LOG_KEY="logs/bootstrap-$INSTANCE_ID.log"
APP_DIR="/var/www/html/nest"

upload_log() {
  aws s3 cp /tmp/nest-bootstrap.log \
    "s3://$S3_LOG_BUCKET/$S3_LOG_KEY" \
    --region "$AWS_REGION" 2>/dev/null || true
}

echo "=== Starting bootstrap $(date) ==="
upload_log

dnf update -y || true

dnf install -y \
  httpd \
  php \
  php-mysqlnd \
  php-xml \
  php-mbstring \
  php-zip \
  php-gd \
  php-curl \
  mariadb105 \
  unzip \
  awscli \
  amazon-ssm-agent

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

aws --version
upload_log

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

DB_NAME=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['db_name'])")
DB_USERNAME=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['db_username'])")
DB_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['db_password'])")
APP_KEY=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['app_key'])")

echo "=== Secrets fetched ==="
upload_log

aws s3 cp "s3://${S3_BUCKET}/Project-2-assets/nest.zip" /tmp/nest.zip --region "$AWS_REGION"
aws s3 cp "s3://${S3_BUCKET}/Project-2-assets/V1__nest.sql" /tmp/V1__nest.sql --region "$AWS_REGION"
aws s3 cp "s3://${S3_BUCKET}/Project-2-assets/AppServiceProvider.php" /tmp/AppServiceProvider.php --region "$AWS_REGION"

echo "=== Assets downloaded ==="
upload_log

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

unzip -q /tmp/nest.zip -d /tmp/
cp -r /tmp/nest/. "$APP_DIR"/
cp /tmp/AppServiceProvider.php "$APP_DIR"/app/Providers/AppServiceProvider.php

# Remove forced HTTPS because ALB currently serves HTTP only
sed -i "/forceScheme/d" "$APP_DIR"/app/Providers/AppServiceProvider.php || true

echo "=== Application extracted ==="
upload_log

cat > "$APP_DIR"/.env <<ENVEOF
APP_NAME="Nest App"
APP_ENV=production
APP_DEBUG=false
APP_KEY=$APP_KEY
APP_URL=$APP_URL

LOG_CHANNEL=daily
BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

DB_CONNECTION=mysql
DB_HOST=$DB_HOST
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_STRICT=false

ADMIN_DIR=admin
BLOG_USE_LANGUAGE_VERSION_2=true
PAGE_USE_LANGUAGE_VERSION_2=true
CMS_ENABLE_INSTALLER=false
ENVEOF

echo "=== .env written ==="
upload_log

until mysqladmin ping \
  -h "$DB_HOST" \
  -u "$DB_USERNAME" \
  -p"$DB_PASSWORD" \
  --silent
do
  echo "Waiting for RDS..."
  sleep 15
done

echo "RDS is ready"

mysql \
  -h "$DB_HOST" \
  -u "$DB_USERNAME" \
  -p"$DB_PASSWORD" \
  "$DB_NAME" < /tmp/V1__nest.sql || true

echo "=== Database imported ==="
upload_log

cd "$APP_DIR"

mysql \
  -h "$DB_HOST" \
  -u "$DB_USERNAME" \
  -p"$DB_PASSWORD" \
  "$DB_NAME" \
  -e "UPDATE settings SET value='$APP_URL' WHERE value='http://localhost' OR value='https://localhost';" || true

php artisan storage:link || true
php artisan optimize:clear || true
php artisan cache:clear || true
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

chown -R apache:apache "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 775 "$APP_DIR"/storage
chmod -R 775 "$APP_DIR"/bootstrap/cache
chmod -R 775 "$APP_DIR"/public

cat > /etc/httpd/conf.d/nest.conf <<EOF
<VirtualHost *:80>
    DocumentRoot $APP_DIR/public

    <Directory $APP_DIR/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog /var/log/httpd/nest-error.log
    CustomLog /var/log/httpd/nest-access.log combined
</VirtualHost>
EOF

rm -f /etc/httpd/conf.d/welcome.conf

sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
  /etc/httpd/conf.modules.d/00-base.conf 2>/dev/null || true

systemctl enable httpd
systemctl restart httpd

if systemctl is-active --quiet httpd; then
  echo "=== Bootstrap complete $(date) ==="
else
  echo "ERROR: Apache failed to start"
  journalctl -u httpd --no-pager -n 50 >> /tmp/nest-bootstrap.log
fi

upload_log