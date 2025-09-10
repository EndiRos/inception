<?php
define('DB_NAME', getenv('WORDPRESS_DB_NAME'));
define('DB_USER', getenv('WORDPRESS_DB_USER'));

// Intentar leer desde secret, fallback a variable de entorno
if (file_exists('/run/secrets/db_password')) {
    define('DB_PASSWORD', trim(file_get_contents('/run/secrets/db_password')));
} else {
    define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
}

define('DB_HOST', getenv('WORDPRESS_DB_HOST'));
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';