#
# == Class: librenms::php-fpm
#
# Configure php-fpm specifically for LibreNMS.
#
class librenms::php_fpm
(

) inherits librenms::params {

  file { 'librenms-etc-php-fpm':
    ensure  => 'present',
    name    => '/etc/php/7.4/fpm/pool.d/librenms.conf',
    content => template('librenms/php-fpm-librenms.erb'),
    mode    => '0644',
    notify  => Service['php-fpm'],
  }

  service { 'php-fpm':
    ensure  => 'running',
    enable  => true,
    name    => 'php7.4-fpm',
    require => [ File['librenms-etc-php-fpm'] ],
  }
}