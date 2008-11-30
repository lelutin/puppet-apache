# manifests/defines/vhost_files.pp

### vhost configuration files
#
# deploy vhost configuration files


# this is a wrapper for apache::vhost::file and avhost::template below
#
# vhost_mode: which option is choosed to deploy the vhost
#   - template: generate it from a template (default)
#   - file: deploy a vhost file (apache::vhost::file will be called directly)
#   
define apache::vhost(
    $path = 'absent',
    $template_mode = 'static',
    $vhost_mode = 'template',
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $content = 'absent',
    $domain = 'absent',
    $domainalias = 'absent',
    $allow_override = 'None',
    $php_upload_tmp_dir = 'absent',
    $php_session_save_path = 'absent',
    $options = 'absent',
    $additional_options = 'absent',
    $template_mode = 'static',
    $ssl_mode = 'false',
    $htpasswd_file = 'absent',
    $htpasswd_path = 'absent',
    $mod_security = 'true'
) {
    # file or template mode?
    case $vhost_mode {
        'file': {
            apache::vhost::file{$name:
                vhost_source => $vhost_source,
                vhost_destination => $vhost_destination,
                htpasswd_file => $htpasswd_file,
                htpasswd_path => $htpasswd_path,
            }
        }
        'template': {
            apache::vhost::template{$name:
                path => $path,
                domain => $domain,
                domainalias => $domainalias,
                php_upload_tmp_dir => $php_upload_tmp_dir,
                php_session_save_path => $php_session_save_path,
                allow_override => $allow_override,
                options => $options,
                additional_options => $additional_options,
                template_mode => $template_mode,
                ssl_mode => $ssl_mode,
                htpasswd_file => $htpasswd_file,
                htpasswd_path => $htpasswd_path,
                mod_security => 'false',
            }
        }
        default: { fail("no such vhost_mode: $vhost_mode defined for $name.") }
    }
    
}

# htpasswd_file: wether to deploy a passwd for this vhost or not
#   - absent: ignore (default)
#   - nodeploy: htpasswd file isn't deployed by this mechanism
#   - else: try to deploy the file
#
# htpasswd_path: where to deploy the passwd file
#   - absent: standardpath (default)
#   - else: path to deploy
#
define apache::vhost::file(
    $vhost_source = 'absent',
    $vhost_destination = 'absent',
    $content = 'absent',
    $htpasswd_file = 'absent',
    $htpasswd_path = 'absent'
){
    $vhosts_dir = $operatingsystem ? {
        centos => "$apache::centos::config_dir/vhosts.d/",
        gentoo => "$apache::gentoo::config_dir/vhosts.d/",
        debian => "$apache::debian::config_dir/vhosts.d/",
        ubuntu => "$apache::ubuntu::config_dir/vhosts.d/",
        openbsd => "$apache::openbsd::config_dir/vhosts.d/",
        default => '/etc/apache2/vhosts.d/',
    }
    $real_vhost_destination = $vhost_destination ? {
        'absent' => "$vhosts_dir/$name.conf",
        default => $vhost_destination,
    } 
    file{"$name.conf":
        path => $real_vhost_destination,
        require => File[vhosts_dir],
        notify => Service[apache],
        owner => root, group => 0, mode => 0644;
    }
    case $content {
        'absent': {
            $real_vhost_source = $vhost_source ? {
                'absent'  => [ 
                    "puppet://$server/files/apache/vhosts.d/$fqdn/$name.conf",
                    "puppet://$server/files/apache/vhosts.d/$apache_cluster_node/$name.conf",
                    "puppet://$server/files/apache/vhosts.d/$name.conf", 
                    "puppet://$server/apache/vhosts.d/$name.conf",
                    "puppet://$server/apache/vhosts.d/$operatingsystem.$lsbdistcodename/$name.conf",
                    "puppet://$server/apache/vhosts.d/$operatingsystem/$name.conf",
                    "puppet://$server/apache/vhosts.d/$name.conf"
                ],
                default => "puppet://$server/$vhost_source",
            }
            File["$name.conf"]{
                source => $real_vhost_source,
            }
        }
        default: {
            File["$name.conf"]{
                content => $content,
            }
        }
    }
    case $htpasswd_file {
        'absent','nodeploy': { info("don't deploy a htpasswd file for ${name") }
        default: { 
            case $htpasswd_path {
                'absent': {
                    $real_htpasswd_path = $operatingsystem ? {
                        gentoo => "$apache::gentoo::config_dir/htpasswds/$name",
                        debian => "$apache::debian::config_dir/htpasswds/$name",
                        ubuntu => "$apache::ubuntu::config_dir/htpasswds/$name",
                        openbsd => "$apache::openbsd::config_dir/htpasswds/$name",
                        default => "/etc/apache2/htpasswds/$name"
                    }
                }
                default: { $real_htpasswd_path = $htpasswd_path }
            }
            file{$real_htpasswd_path:
                source => [ "puppet://$server/files/apache/htpasswds/$fqdn/$name",
                            "puppet://$server/files/apache/htpasswds/$apache_cluster_node/$name",
                            "puppet://$server/files/apache/htpasswds/$name" ],
                owner => root, group => 0, mode => 0644;
            }
        }
    }
}

# template_mode:
#   - php -> for a default php application
#   - static -> for a static application (default)
#
# ssl_mode: wether this vhost supports ssl or not
#   - false: don't enable ssl for this vhost (default)
#   - true: enable ssl for this vhost
#   - force: enable ssl and redirect non-ssl to ssl
#
define apache::vhost::template(
    $path = 'absent',
    $domain = 'absent',
    $domainalias = 'absent',
    $allow_override = 'None',
    $php_upload_tmp_dir = 'absent',
    $php_session_save_path = 'absent',
    $options = 'absent',
    $additional_options = 'absent',
    $template_mode = 'static', 
    $ssl_mode = 'false',
    $mod_security = 'true',
    $htpasswd_file = 'absent',
    $htpasswd_path = 'absent'
){
    $real_path = $path ? {
        'absent' => $operatingsystem ? {
            openbsd => "/var/www/htdocs/$name",
            default => "/var/www/$name"
        },
        default => $path
    }

    $documentroot = "$real_path/www"
    $logdir = "$real_path/logs"

    $servername = $domain ? {
        'absent' => $name,
        default => $domain
    }
    $serveralias = $domainalias ? {
        'absent' => '',
        default => $domainalias
    }
    case $htpasswd_path {
        'absent': {
            $real_htpasswd_path = $operatingsystem ? {
                gentoo => "$apache::gentoo::config_dir/htpasswds/$name",
                debian => "$apache::debian::config_dir/htpasswds/$name",
                ubuntu => "$apache::ubuntu::config_dir/htpasswds/$name",
                openbsd => "$apache::openbsd::config_dir/htpasswds/$name",
                default => "/etc/apache2/htpasswds/$name"
            }
        }
        default: { $real_htpasswd_path = $htpasswd_path }
    }
    apache::vhost::file{$name:
        content => template("apache/vhosts/$template_mode/$operatingsystem.erb"),
        htpasswd_file => $htpasswd_file,
        htpasswd_path => $htpasswd_path,
    }
}