# Small helpers for stabilising and compressing videos with `ffmpeg`
use std

# returns a default string value if a condition is met
# e.g.
# > true | defaultIfStr "helloworld"
# "helloworld"
# > false | defaultIfStr "asdasd"
# ""
def defaultIfStr [
  default : string
]: bool -> string {
  let condition = $in
  if $condition {
    $default
  } else {
    ""
  }
}

# returns a default string value if a condition is met
# e.g.
# > true | maybeArgList "-codec:v" "libx264"
# ["-codev:v" "libx264"]
# > false | maybeArgList "-asd" "sssss"
# []
def maybeArgList [
  arg : string
  val : string
]: bool -> list<string> {
  let condition = $in
  if $condition {
    [$arg $val]
  } else {
    []
  }
}

def parseFile [ ]: path -> record {
  $in | parse "{name}.{ext}" | get 0
}

module ffmpeg-wrap {

  # generate a stabilisation transformation
  export def genTransformationsStr [
    --shakiness(-h) = 10
    --accuracy(-a) = 15
    --stepsize(-s) = 6
    --result(-r) : string = "" # file name (should end in trf), i.e. myvid.trf
  ] {
    # $"vidstabdetect=stepsize=($stepsize):shakiness=($shakiness):accuracy=($accuracy):result=($file)"
    $"vidstabdetect=stepsize=($stepsize):shakiness=($shakiness):accuracy=($accuracy)(($result != "") | defaultIfStr $result)"
  }

  # No such filter: 'vidstabdetect'
  # means you need a more fully compiled version of ffmpeg, e.g. `nix shell nixos#ffmpeg-full`
  export def genTransformations [
    file  # video file
    shakiness = 10
    accuracy = 15
    stepsize = 6
  ] {
    let f = ($file | parse "{name}.{ext}" | get 0)
    # let starStr = $"vidstabdetect=stepsize=($stepsize):shakiness=($shakiness):accuracy=($accuracy):result=($f.name).trf"
    let stabStr = (genTransformationsStr -h $shakiness -a $accuracy -s $stepsize -r $"(f.name).trf")
    let out = (run-external "ffmpeg"  "-i" $file "-vf" $stabStr "-f" "null" "-" e+o>| complete)
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
      ansi reset
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

  # run an ffmpeg command on a single file
  export def runCmd [
    input # path to input file
    --output : path # optional path to output file
    --copy = true # whether to copy
    --hwaccel : string = "auto" # which hwaccel to use, set to "" to disable, i.e. `vaapi`
    --hw : string = "" # set to "gpu" to use gpu for compression
    --extraPre(-p) : list<string> = [] # which hwaccel_output_format to use, set to "" to disable, i.e. `vaapi`
    --outputFormat : string = "mov" # output file format
    --start : string = "" # start timestamp to cut video at, i.e. "00:01:03.000"
    --end : string = "" # end timestamp to cut video at, i.e. "00:02:15.000"
    --compress(-c) # pass flag to enable compression
    --codec : string = "libx264" # codec to use for output file
    --crf : int = 18 # (compression) crf
    --preset : string = "slow" # (compression) preset to use
    --pixfmt : string = "yuv420p" # (compression) pixfmt
    --stabilise(-s) # pass flag to enable stabilisation
    --smoothing : int = 20 # (stabilisation) smoothing
    --shakiness : int = 10 # (stabilisation) shakiness
    --accuracy : int = 15 # (stabilisation) accuracy
    --stepsize : int = 6 # (stabilisation) stepsize
    ...extraArgs : list<string> # extra args to add to ffmpeg command
  ] {
    # let file = ($input | parse "{name}.{ext}" | get 0)
    let file = ($input | parseFile)
    let outputFile = (
      $output | default
      $"($file.name)($compress | defaultIfStr '-compressed')-($stabilise | defaultIfStr '-stabilised').($outputFormat)"
    )
    let acceleration = (
      if $hwaccel == "" {[]} else
      if $hwaccel == "vaapi" {[
        "-hwaccel" "vaapi"
        "-hwaccel_output_format" "vaapi"
      ]} else {[
        "-hwaccel" $hwaccel
      ]})
    let args = ($acceleration
      | append [ "-i" $input ]
      | append (($start != "") | maybeArgList "-ss" $start)
      | append (($end != "") | maybeArgList "-to" $end)
      | append ($compress | maybeArgList "-codec:v" $codec)
      | append ($compress | maybeArgList "-crf" ($crf | into string))
      | append (($compress and $preset != "") | maybeArgList "-preset" $preset)
      | append (($compress and $pixfmt != "") | maybeArgList "-pix_fmt" $pixfmt)
      | append ($copy | maybeArgList "-c:a" copy)
      | append ($stabilise | maybeArgList "-vf" $"vidstabtransform=smoothing=($smoothing):input=($file.name).trf")
      | append $outputFile
      | append (($hwaccel == "vaapi" and $hw == "gpu") | maybeArgList "-vf" "format=vaapi,hwupload")
      | append $extraArgs
      | flatten --all
    )
    print $"Running `ffmpeg ($args | str join ' ')`"
    let out = (run-external ffmpeg ...$args e+o>| complete)
    if ($out | get -i stderr | default "" | str contains "No such filter: 'vidstabdetect'") {
      print $out
      ansi red
      print "you need a full version of ffmpeg with filters compiled in, in nix `nix shell nixos#ffmpeg-full`"
      ansi reset
    } else if ($out.exit_code != 0) {
      print $out
      ansi red
      print "Some unknown error occured."
      ansi reset
    } else {
      ansi green
      print $"Succeeded in creating transformations for ($file.name) -> ($outputFile)."
      ansi reset
    }
    $out
  }

  export def main [] {
    listCustomCommands "ffmpeg-wrap"
  }

}

export use ffmpeg-wrap
