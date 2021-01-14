#
# == Class: librenms::php
#
# Configure php specifically for LibreNMS.
#
class librenms::php
(
  String  $php_timezone,
) inherits librenms::params {

  package {[ 'composer', 'php7.4', 'php7.4-mysql', 'php7.4-gd',
    'php7.4-cli', 'php-pear', 'php7.4-curl', 'php7.4-fpm',
    'php7.4-snmp', 'php-net-ipv6', 'php7.4-zip',
    'php7.4-mbstring', 'php7.4-json', 'php7.4-memcached',
    'php7.4-xml']:
  ensure => 'present',
  before => Class['librenms::install'],
  }

  # validate.php will complain if PHP timezone is missing
  file { '/etc/php/7.4/cli/conf.d/30-timezone.ini':
    ensure  => 'present',
    content => "date.timezone = ${php_timezone}\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['php7.4-cli'],
  }

  file { 'librenms-etc-php-fpm':
    ensure  => 'present',
    name    => '/etc/php/7.4/fpm/pool.d/librenms.conf',
    content => template('librenms/php-fpm-librenms.erb'),
    mode    => '0644',
    notify  => Service['php-fpm'],
    require => Package['php7.4-fpm'],
  }

  service { 'php-fpm':
    ensure  => 'running',
    enable  => true,
    name    => 'php7.4-fpm',
    require => [ File['librenms-etc-php-fpm'] ],
  }
}