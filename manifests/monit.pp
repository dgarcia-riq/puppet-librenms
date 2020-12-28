#
# == Class: librenms::monit
#
# Configure monit specifically for LibreNMS.
#
class librenms::monit
(
  $ip,
  $admin_pass,
) {
  ensure_resource('package', 'monit', { 'ensure' => 'present' })

  file { 'librenms-etc-monit-monitrc':
    ensure  => 'present',
    name    => '/etc/monit/monitrc',
    content => template('monitrc.erb'),
    owner   => $::os::params::adminuser,
    group   => $::os::params::admingroup,
    mode    => '0600',
    require => Package['monit'],
    notify  => Service['monit'],
  }

  file { 'librenms-etc-monit-rrdcached':
    ensure  => 'present',
    name    => '/etc/monit/conf.d/rrdcached',
    content => template('monit-rrdcached.erb'),
    owner   => $::os::params::adminuser,
    group   => $::os::params::admingroup,
    mode    => '0644',
    require => Package['monit'],
    notify  => Service['monit'],
  }

  file { 'librenms-etc-monit-memcached':
    ensure  => 'present',
    name    => '/etc/monit/conf.d/memcached',
    content => template('monit-memcached.erb'),
    owner   => $::os::params::adminuser,
    group   => $::os::params::admingroup,
    mode    => '0644',
    require => Package['monit'],
    notify  => Service['monit'],
  }

  service { 'librenms-monit':
    ensure  => 'running',
    enable  => true,
    name    => 'monit',
    require => [ File['librenms-etc-monit-monitrc'] ],
  }
}