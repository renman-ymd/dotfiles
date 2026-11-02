source ~/.config/nushell/completions/jj.nu

def copypath [] { $env.PWD | pbcopy }
def copyfile [file: path] { open --raw $file | pbcopy }

def google [query: string] {
  ^open $"https://www.google.com/search?q=($query | url encode)"
}

def extract [file: path] {
  let f = ($file | into string)
  if ($f | str ends-with ".tar.gz") or ($f | str ends-with ".tgz") {
    ^tar xzf $file
  } else if ($f | str ends-with ".tar.bz2") {
    ^tar xjf $file
  } else if ($f | str ends-with ".tar.xz") {
    ^tar xJf $file
  } else if ($f | str ends-with ".tar.zst") {
    ^tar --zstd -xf $file
  } else {
    match ($file | path parse | get extension) {
      "zip" => { ^unzip $file }
      "tar" => { ^tar xf $file }
      "gz" => { ^gunzip $file }
      "bz2" => { ^bunzip2 $file }
      "xz" => { ^xz -d $file }
      "7z" => { ^7z x $file }
      "rar" => { ^unrar x $file }
      $ext => { error make { msg: $"Unknown archive type: ($ext)" } }
    }
  }
}

def em-kill [] {
  ^emacsclient -s main --eval "(kill-emacs)"
}

def em-restart [] {
    ^launchctl kickstart -k $"gui/(^id -u | str trim)/org.gnu.emacs.daemon"
}

$env.config.keybindings ++= [{
  name: prepend_sudo
  modifier: alt
  keycode: char_s
  mode: [emacs vi_insert vi_normal]
  event: [
    { edit: MoveToStart }
    { edit: InsertString, value: "sudo " }
  ]
}]

# show directory content after every cd
$env.config.hooks.env_change.PWD ++= [{|before, after|
  if $before != null {
    print $after
    ls --all --short-names | print
  }
}]
