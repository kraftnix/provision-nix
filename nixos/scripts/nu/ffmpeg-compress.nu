# Small helpers for stabilising and compressing videos with `ffmpeg`
use std

module ffmpeg-compress {

  # No such filter: 'vidstabdetect'
  # means you need a more fully compiled version of ffmpeg, e.g. `nix shell nixos#ffmpeg-full`
  export def genTransformations [
    file  # video file
    shakiness = 10
    accuracy = 15
    stepsize = 6
  ] {
    let f = ($file | parse "{name}.{ext}" | get 0)
    let starStr = $"vidstabdetect=stepsize=($stepsize):shakiness=($shakiness):accuracy=($accuracy):result=($f.name).trf"
    let out = (run-external "ffmpeg"  "-i" $file "-vf" $starStr "-f" "null" "-" e+o>| complete)
    if ($out.stderr | str contains "No such filter: 'vidstabdetect'") {
      $out
      ansi red
      print "you need a full version of ffmpeg with filters compiled in, in nix `nix shell nixos#ffmpeg-full`"
      ansi reset
    } else if ($out.exit_code != 0) {
      $out
      ansi red
      print "Some unknown error occured, here is the output:"
      ansi reset
    } else {
      ansi green
      print $"Succeeded in creating transformations"
    }
  }

  # compress and stabilise video file with ffmpeg
  export def compressAndStabilise [
    file  # video file
    smoothing = 20
    codec = libx264
    crf = 18
    preset = slow
    pixfmt = yuv420p
    outputFormat = mov
  ] {
    let f = ($file | parse "{name}.{ext}" | get 0)
    let stab = $"vidstabtransform=smoothing=($smoothing):input=($f.name).trf"
    let out = (run-external
      ffmpeg  "-i" $file
              "-vf" $stab
              "-codec:v" $codec
              "-crf" $crf
              "-preset" $preset
              "-pix_fmt" $pixfmt
              "-c:a" copy
              $"($f.name)-compressed-stabilised.($outputFormat)"
      e+o>| complete)
    if ($out.stderr | str contains "No such filter: 'vidstabdetect'") {
      $out
      ansi red
      print "you need a full version of ffmpeg with filters compiled in, in nix `nix shell nixos#ffmpeg-full`"
      ansi reset
    } else if ($out.exit_code != 0) {
      $out
      ansi red
      print "Some unknown error occured, here is the output:"
      ansi reset
    } else {
      ansi green
      print $"Succeeded in creating transformations"
    }
  }

  # list all media formats inside a directory
  export def getAllMediaFormats [
    path? = null : string   # optional directory
    --formats(-f) = [ "MP4" "mp4" "mov" "MOV" "avi" "AVI" ] # names of formats to search for
  ] {
    print $"Getting all media formats at ($path)"
    if ($path != null) {
      ls $path
    } else {
      ls
    } | where { |file|
      let f = ($file.name | parse "{name}.{ext}");
      ($f | length) > 0 and ($formats | any { |e| $e == $f.0.ext })
    }
  }

  # compress and stabilise all videos in directory
  export def compressAll [
    path? = null : string   # optional directory
  ] {
    if ($path != null) {
      getAllMediaFormats $path
    } else {
      getAllMediaFormats
    } | each { |file|
      genTransformations $file.name
      compressAndStabilise $file.name
    }
  }

  export def main [] {
    listCustomCommands "ffmpeg-compress"
  }

}

export use ffmpeg-compress
