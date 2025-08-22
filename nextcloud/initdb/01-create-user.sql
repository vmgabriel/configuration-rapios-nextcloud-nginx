CREATE USER IF NOT EXISTS 'nextcloud'@'%' IDENTIFIED BY 'nextcloudpass';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';
FLUSH PRIVILEGES;
