define apache::file::rw() {
    file{$name:
      mode => 660,
      recurse => true
    }
}

define apache::file::readonly() {
  apache::file::r{$name:}
}
define apache::file::r() {
    file{$name:
      mode    => 640,
      recurse => true,
    }
}

define apache::dir::rw(
    $uid = 'absent',
    $gid = 'uid'
){
    file{$name:
	ensure => directory,
        mode   => 0770,
    }
    selinux::dir::rw{$name:}
}
