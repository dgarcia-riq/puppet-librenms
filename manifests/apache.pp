#
# == Class: librenms::apache
#
# Configure apache specifically for LibreNMS.
#
class librenms::apache
(
  String  $apache_servername,
          $crt_filepath,
          $key_filepath,
)
{
    class { '::apache':
      purge_configs => true,
      default_vhost => false,
      mpm_module    => 'prefork',
    }

    include ::apache::mod::php
    include ::apache::mod::headers
    include ::apache::mod::rewrite
    include ::apache::mod::ssl
    include ::apache::mod::proxy_fcgi
    include ::apache::mod::setenvif

    apache::vhost { 'librenms':
      servername      => $apache_servername,
      port            => '80',
      docroot         => '/opt/librenms/html',
      docroot_owner   => 'librenms',
      docroot_group   => 'librenms',
      proxy_pass      =>
      [
        {
          'path' => '/opt/librenms/html/',
          'url'  => '!',
        }
      ],
      directories     =>
        [
          {
            'path'           => '/opt/librenms/html/',
            'options'        => [ 'Indexes', 'FollowSymLinks', 'MultiViews' ],
            'allow_override' => 'All'
          }
        ],
      request_headers =>  [ 'set X-Forwarded-Proto "http"', 'set X-Forwarded-Port "80"' ],
      headers         => [ 'always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"' ],
      setenvifnocase  => '^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1',
      custom_fragment => '
      <FilesMatch ".+\.php$">
        SetHandler "proxy:unix:/run/php-fpm-librenms.sock|fcgi://localhost"
      </FilesMatch>',
    }

    file { '/etc/ssl/certs/librenms':
      ensure => directory,
    }

    file { "${apache_servername}.crt":
      ensure  => present,
      path    => "/etc/ssl/certs/librenms/${apache_servername}.crt",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => "${crt_filepath}${apache_servername}.crt",
      require => File['/etc/ssl/certs/librenms'],
    }

    file { "${apache_servername}.key":
      ensure  => present,
      path    => "/etc/ssl/certs/librenms/${apache_servername}.key",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => "${key_filepath}${apache_servername}.key",
      require => File['/etc/ssl/certs/librenms'],
    }

    apache::vhost { 's_librenms':
      servername            => $apache_servername,
      port                  => '443',
      docroot               => '/opt/librenms/html',
      docroot_owner         => 'librenms',
      docroot_group         => 'librenms',
      ssl                   => true,
      ssl_cert              => "/etc/ssl/certs/librenms/${apache_servername}.crt",
      ssl_key               => "/etc/ssl/certs/librenms/${apache_servername}.key",
      directories           =>
        [
          {
            'path'           => '/opt/librenms/html/',
            'allow_override' => 'All',
            'require'        => 'all granted',
            'options'        => [ 'FollowSymLinks', 'MultiViews' ],
          }
        ],
      allow_encoded_slashes => 'nodecode',
      require               => [ File["${apache_servername}.crt"],File["${apache_servername}.key"] ] ,
      setenvifnocase        => '^Authorization$ "(.+)" HTTP_AUTHORIZATION=$1',
      custom_fragment       => '
      <FilesMatch ".+\.php$">
        SetHandler "proxy:unix:/run/php-fpm-librenms.sock|fcgi://localhost"
      </FilesMatch>',
    }
}
