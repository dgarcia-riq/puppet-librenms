#
# == Class: librenms::memcached
#
# Configure memcached specifically for LibreNMS.
#
class librenms::memcached
(

) inherits librenms::params {

  ensure_resource('package', 'memcached', { 'ensure' => 'present' })

  file { 'librenms-etc-memcached':
    ensure  => 'present',
    name    => '/etc/memcached.conf',
    content => template('librenms/memcached.erb'),
    mode    => '0644',
    require => Package['memcached'],
    notify  => Service['librenms-memcached'],
  }

  service { 'librenms-memcached':
    ensure  => 'running',
    enable  => true,
    name    => 'memcached',
    require => [ File['librenms-etc-memcached'] ],
  }
}