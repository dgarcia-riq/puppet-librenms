#
# == Class: librenms::config
#
# Configure a virtual host for LibreNMS
#
class librenms::config
(
  String  $system_user,
          $basedir,
  String  $server_name,
  String  $admin_user,
  String  $admin_pass,
  String  $admin_email,
          $db_user,
          $db_host,
          $db_pass,
  Hash[String, Integer[0,1]] $poller_modules,
  String  $poller_threads,
  String  $rrdcached,
  String  $rrdtool_version,
  String  $distributed_poller_memcached_host,
  String  $distributed_poller_group,
  String  $community,
  Optional[String] $extra_config_file = undef,

) inherits librenms::params {
    File {
      ensure => 'present',
      mode   => '0755',
    }

    # Construct the poller module hash, with defaults coming from params.pp
    $l_poller_modules = merge($::librenms::params::default_poller_modules, $poller_modules)

    file { 'librenms-config.php':
      path    => "${basedir}/config.php",
      owner   => $system_user,
      group   => $system_user,
      content => template('librenms/config.php.erb'),
      require => Class['librenms::install'],
    }

    Exec {
      user => $::os::params::adminuser,
      path => [ '/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin' ],
    }

    $build_base_php_require = File['librenms-config.php']

    exec { 'librenms-composer_wrapper.php':
      command => "php ${basedir}/scripts/composer_wrapper.php install --no-dev && touch ${basedir}/.composer_wrapper.php-ran",
      creates => "${basedir}/.composer_wrapper.php-ran",
      require => $build_base_php_require,
    }

    exec { 'librenms-adduser.php':
      command => "php ${basedir}/adduser.php ${admin_user} ${admin_pass} 10 ${admin_email} && touch ${basedir}/.adduser.php-ran",
      creates => "${basedir}/.adduser.php-ran",
      require => $build_base_php_require,
    }

    file { '/etc/cron.d/librenms':
      ensure  => 'present',
      content => template('librenms/cron.erb'),
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Class['librenms::install'],
    }

    file { [ '/data', '/data/backup' ]:
      ensure  => 'directory',
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      require => Class['librenms::install'],
    }

## mysql backup and maintenance
    cron { 'librenms_mysqlbackup':
      command => "
                  /usr/bin/mysqldump -p${db_pass} -u ${db_user} librenms >> \
                  /data/backup/librenms-`date +\"%m%d%Y\"`.sql 2> /dev/null && echo \"librenms backup completed: `date`\" > \
                  /var/log/mysql/librenms-backup.log",
      user    => 'root',
      hour    => '2',
      minute  => '30',
    }

    cron { 'librenms_mysqlbackup_cleanup':
      command  => "
                  find /data/backup/ -name *.sql -mtime +30 -exec rm -f {} \; 2> /dev/null && \
                  echo \"librenms backup cleanup completed: `date`\" > /var/log/mysql/librenms-backup_cleanup.log",
      user     => 'root',
      hour     => '2',
      minute   => '35',
      monthday => '1',
    }

    file_line { 'mysql_env':
      ensure => present,
      path   => "${basedir}/.env",
      line   => "DB_HOST=${db_host}",
      match  => 'DB_HOST=',
    }
##

## for post install ${basedir}/validate.php requirements
    exec { 'pip3_PyMySQL_root_require':
      command => "pip3 install -r ${basedir}/requirements.txt && touch /.pip3_PyMySQL_root_require_done",
      path    => ['/usr/bin/'],
      creates => '/.pip3_PyMySQL_root_require_done',
      require => $build_base_php_require,
    }

    exec { 'pip3_PyMySQL_librenms_require':
      command => "pip3 install -r ${basedir}/requirements.txt && touch ${basedir}/.pip3_PyMySQL_librenms_require_done",
      path    => ['/usr/bin/'],
      user    => 'librenms',
      creates => "${basedir}/.pip3_PyMySQL_librenms_require_done",
      require => $build_base_php_require,
    }

    exec { 'php_timezone_cli_require':
      command => "sed -i \"s,;date.timezone\ =,date.timezone\ = \"America/Los_Angeles\",g\" /etc/php/7.4/cli/php.ini \
                  && touch /.php_timezone_cli_require_done",
      creates => '/.php_timezone_cli_require_done',
      require => $build_base_php_require,
    }

    exec { 'php_timezone_apache2_require':
      command => "sed -i \"s,;date.timezone\ =,date.timezone\ = \"America/Los_Angeles\",g\" /etc/php/7.4/apache2/php.ini \
                  && touch /.php_timezone_apache2_require_done",
      creates => '/.php_timezone_apache2_require_done',
      notify  => Class['Apache::Service'],
      require => Class['Apache'],
    }

    exec { 'php_timezone_fpm_require':
      command => "sed -i \"s,;date.timezone\ =,date.timezone\ = \"America/Los_Angeles\",g\" /etc/php/7.4/fpm/php.ini \
                  && touch /.php_timezone_fpm_require_done",
      creates => '/.php_timezone_fpm_require_done',
      notify  => Service['php-fpm'],
      require => $build_base_php_require,
    }

    exec { 'mysql_utf8_require':
      command => "echo 'ALTER DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;' | \
                  mysql -p${db_pass} -u ${db_user} librenms && touch /.mysql_utf8_require_done",
      creates => '/.mysql_utf8_require_done',
      require => $build_base_php_require,
    }

    exec { 'dir_perm_require':
      command => "chown -R librenms:librenms ${basedir} && \
                  setfacl -d -m g::rwx ${basedir}/logs ${basedir}/bootstrap/cache/ ${basedir}/storage/ && \
                  chmod -R ug=rwX ${basedir}/logs ${basedir}/bootstrap/cache/ ${basedir}/storage/ \
                  && touch /.dir_perm_require_done",
      creates => '/.dir_perm_require_done',
      require => Class['librenms::install'],
    }

    exec { 'github_remove_require':
      command => "git config --global user.email librenms@${server_name} ; git config --global user.name librenms ; \
                  git reset -q  ; \
                  git checkout . ; \
                  git clean -d -f app bootstrap contrib database doc html includes LibreNMS licenses \
                  mibs misc resources routes scripts sql-schema tests ; \
                  git checkout .gitignore bootstrap/cache/.gitignore logs/.gitignore rrd/.gitignore \
                  storage/app/.gitignore storage/app/public/.gitignore \
                  storage/debugbar/.gitignore storage/framework/cache/.gitignore \
                  storage/framework/cache/data/.gitignore storage/framework/sessions/.gitignore \
                  storage/framework/testing/.gitignore storage/framework/views/.gitignore storage/logs/.gitignore \
                  && touch ${basedir}/.github_remove_require_done ;\
                  chown librenms:librenms .git/index",
      cwd     => $basedir,
      user    => 'librenms',
      creates => "${basedir}/.github_remove_require_done",
      require => Exec['dir_perm_require'],
    }

    exec { 'lnms_shortcut_require':
      command => 'ln -s /opt/librenms/lnms /usr/local/bin/lnms && touch /.lnms_shortcut_require_require_done',
      path    => ['/bin/'],
      creates => '/.lnms_shortcut_require_require_done',
      require => $build_base_php_require,
    }

    exec { 'bash_completion_require':
      command => 'cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/ && touch /.bash_completion_require_done',
      path    => ['/bin/'],
      creates => '/.bash_completion_require_done',
      require => $build_base_php_require,
    }

    exec { 'log_rotation_require':
      command => 'cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms && touch /.log_rotation_require_done',
      path    => ['/bin/'],
      creates => '/.log_rotation_require_done',
      require => $build_base_php_require,
    }
##
}
