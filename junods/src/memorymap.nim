from strutils import toHex, toLower, join, splitWhitespace, contains, repeat
from sequtils import map
import macros

import values

type
  JAddr* = distinct int64
const NOFF* = -1.JAddr

proc `==`*(a,b: JAddr): bool {.borrow.}
proc `+`*(a,b: JAddr): JAddr =
  if   b == NOFF: return a
  elif a == NOFF: return b
  return (a.int64 + b.int64).JAddr
proc `-`*(a,b: JAddr): JAddr =
  if   b == NOFF: return  a
  elif a == NOFF: return  NOFF
  return (a.int64 - b.int64).JAddr
proc `and`*(a,b: JAddr): JAddr {.borrow.}
proc `and`*(a: JAddr, b: int): JAddr =
  return a and b.JAddr
proc `or`*(a,b: JAddr): JAddr {.borrow.}
proc `shl`*(a:JAddr, b: int): JAddr {.borrow.}
proc `shr`*(a:JAddr, b: int): JAddr {.borrow.}
proc toHex*(a:JAddr, n: int): string {.borrow.}
proc `$`*(a:JAddr): string =
  if a == NOFF:
    return ""
  result = "0x" & a.toHex(8).toLower()
proc repr*(a:JAddr): string =
  result = "0x" & a.toHex(8).toLower()

proc normalize*(offset: JAddr): JAddr =
  if offset == NOFF:
    return offset
  let n3: JAddr = (offset and 0x7f000000)
  let n2: JAddr = (offset and 0x007f0000) or ((offset and 0x00800000) shl 1)
  let n1: JAddr = (offset and 0x00007f00) or ((offset and 0x00008000) shl 1)
  let n0: JAddr = (offset and 0x0000007f) or ((offset and 0x00000080) shl 1)
  return (n3 or n2 or n1 or n0) and 0x7f7f7f7f

proc `+=`*(n1: var JAddr, n2: JAddr) =
  n1 = normalize(n1 + n2)


type
  Kind* = enum
    TNone,
    TBool,
    TNibble,
    TEnum,
    TByte,
    TNibblePair,
    TNibbleQuad,
    TName,
    TName16

proc value*(kind: Kind, b: seq[byte]): int =
  case kind
  of TByte:   result = b[0].int and 0x7f
  of TNibble: result = b[0].int and 0x0f
  of TNibblePair:
    result = ((b[1].int and 0x0f00) shl 4) or
              (b[0].int and 0x000f)
  of TNibbleQuad:
    result = ((b[3].int and 0x0f0000) shl 12) or
             ((b[2].int and 0x000f00) shl  8) or
             ((b[1].int and 0x000f00) shl  4) or
              (b[0].int and 0x00000f)
  else:
    result = b[0].int



### macros section

proc unrecognized(args: varargs[string]) {.compileTime.} =
  echo "unrecognized: ", args.join(" ")

proc id_string(input: NimNode): string {.compileTime.} =
  result = case input.kind
  of nnkIntLit:
    $input.intVal()
  of nnkStrLit, nnkIdent:
    input.strVal()
  else:
    unrecognized "id = " & input[1].treeRepr
    ""


macro genCMap(calls: untyped): untyped =
  let mem_t   = "&(const capmix_mem_t)"
  let area_t = "(const capmix_mem_t *[])"
  var source: seq[string] = @["#include \"cmap.h\"", "", "#include \"values.c\""]
  var level = 0

  proc parseOuter(list: NimNode)

  proc tabs(): string = "\t".repeat(level)

  proc offset_spec[T: Ordinal](offset: T): string =
    result = ".offset = 0x" & offset.toHex(8).toLower() & ", "
  proc offset_spec(node: NimNode): string =
    result = offset_spec node.intVal()

  proc kind_spec(kind: string, c: seq[NimNode]): string =
    result = ".kind = " & kind & ", "
    case kind
    of "TByte","TNibble","TNibblePair","TNibbleQuad":
      result &= ".low = "  & $c[0].intVal() & ", "
      result &= ".high = " & $c[1].intVal() & ", "
    of "TEnum":
      case c[0].kind
      of nnkStrLit:
        result &= ".values = (const char *[]){"
        result &= c[0].strVal().splitWhitespace().map(proc(x:string):string = "\"" & x & "\"").join(",")
        result &= "}, "
      of nnkIdent:
        result &= ".values = " & $c[0].strVal() & ", "
      else:
        unrecognized "TEnum values = " & c[0].treeRepr
    of "TBool", "TName", "TName16":
      discard
    else:
      result = ".area = " & kind & ", "
      #unrecognized "getCMap kind = " & kind
  proc kind_spec(node: NimNode, c: seq[NimNode]): string =
    result = node.strVal().kind_spec(c)

  proc area_spec(id: NimNode): string =
    result = ".area = " & id.strVal() & ", "

  proc repeat_kind[T: Ordinal](kind_spec: string, times, span: T): string =
    for i in 0..<times:
      let name = $(i + 1)
      result &= tabs() & mem_t & "{ "
      result &= offset_spec(i * span)
      result &= ".name = \"" & name & "\", "
      result &= kind_spec & "},\n"
    result = result[0..^2]
  proc repeat_kind_range[T: Ordinal](kind_spec: string, low, high, span: T): string =
    for i in low..high:
      let name = $(i)
      result &= tabs() & mem_t & "{ "
      result &= offset_spec((i - low) * span)
      result &= ".name = \"" & name & "\", "
      result &= kind_spec & "},\n"
    result = result[0..^2]
  proc repeat_kind[T: Ordinal](kind_spec: string, rng: NimNode, step: T): string =
    case rng.kind
    of nnkInfix:
      result = repeat_kind_range(kind_spec, rng[1].intVal(), rng[2].intVal(), step)
    of nnkIntLit:
      result = repeat_kind(kind_spec, rng.intVal(), step)
    else:
      unrecognized "repeat_kind range = " & rng.treeRepr


  proc repeat_area[T: Ordinal](id: NimNode, times, span: T): string =
    for i in 0..<times:
      let name = $(i + 1)
      result &= tabs() & mem_t & "{ "
      result &= offset_spec(i * span)
      result &= ".name = \"" & name & "\", "
      result &= area_spec(id) & "},\n"
    result = result[0..^2]

  proc name_spec(node: NimNode): string =
    result = ".name = \"" & node.id_string() & "\", "

  proc parseArea(id, list: NimNode): string =
    var line = ""
    line &= tabs() & mem_t & "{ " & name_spec(id)
    line &= ".area = "
    case list.kind
    of nnkIdent:
      line &= list.strVal()
      line &= "},"
    of nnkStmtList:
      line &= area_t & "{"
      source.add line
      parseOuter(list)
      source.add tabs() & "\tENDA"
      line = "}},"
    else:
      unrecognized "parseArea = " & list.treeRepr

    result = line

  proc parseMem(offset, name, kind: NimNode, params: seq[NimNode] = @[]): string =
    result = tabs() & mem_t & "{ "
    result &= offset_spec( offset )
    result &= name_spec( name )
    case kind.kind
    of nnkIdent:
      result &= kind_spec( kind, params )
    of nnkStmtList:
      if kind.len == 1 and kind[0].kind == nnkIdent:
        result &= ".area = " & kind[0].strVal() & ", "
      else:
        source.add result & ".area = " & area_t & "{ // parseMem"
        parseOuter(kind)
        source.add tabs() & "\tENDA"
        result = tabs() & "}"
    else:
      unrecognized "parseMem kind = " & kind.treeRepr
    result &= "},"

  proc parseOuter(list: NimNode) =
    inc level
    list.expectKind nnkStmtList
    for c in list:
      var line = ""
      case c.kind
      of nnkCommand:
        let first = c[0]
        case first.kind
        of nnkIntLit:               # 0x00
          case c[1].kind
          of nnkCommand:            # 0x00 name TKind
            c[1].expectKind nnkCommand
            line &= parseMem(c[0], c[1][0], c[1][1], c[2..^1])
          of nnkIdent:              # 0x00 name: other
            if c[1].strVal().contains "reserved":
              continue
            line &= parseMem(c[0], c[1], c[2])
          of nnkIntLit:
            line &= parseMem(c[0], c[1], c[2])
          else:
            unrecognized "parseOuter after offset = " & c[1].treeRepr
        of nnkCall:                 # repeat(n,m) TKind, param, param
          if first[0].kind == nnkIdent and first[0].strVal() == "repeat":
            line &= repeat_kind( kind_spec(c[1], c[2..^1]), first[1], first[2].intVal() )
        else:
          unrecognized "getCMap first = " & first.treeRepr
      of nnkCall: # section:
        line &= tabs()
        line &= parseArea(c[0], c[1])
      else:
        unrecognized "getCMap c in list = " & c.treeRepr

      source.add line
    dec level

  calls.expectKind nnkStmtList
  for call in calls:
    call.expectKind(nnkCall)
    let id = call[0].strVal()
    source.add "static const capmix_mem_t *" & id & "[] = {"
    call[1].parseOuter()
    source.add "\tENDA"
    source.add "};"
  source.add """
    const capmix_mem_t **top_area = juno_map;
  """
  "src/cmap.c".writeFile(source.join("\n"))



### map definitions

genCMap:
  voice_reserves: repeat(16, 1) TByte, 0, 64
  parameters_20: repeat(20, 4) TNibbleQuad, 12768, 52768
  parameters_32: repeat(32, 4) TNibbleQuad, 12768, 52768
  scale_map:
    0x00  "c"   TByte, 0, 127   # -64 .. +63
    0x01  "c#"  TByte, 0, 127   # -64 .. +63
    0x02  "d"   TByte, 0, 127   # -64 .. +63
    0x03  "d#"  TByte, 0, 127   # -64 .. +63
    0x04  "e"   TByte, 0, 127   # -64 .. +63
    0x05  "f"   TByte, 0, 127   # -64 .. +63
    0x06  "f#"  TByte, 0, 127   # -64 .. +63
    0x07  "g"   TByte, 0, 127   # -64 .. +63
    0x08  "g#"  TByte, 0, 127   # -64 .. +63
    0x09  "a"   TByte, 0, 127   # -64 .. +63
    0x0a  "a#"  TByte, 0, 127   # -64 .. +63
    0x0b  "b"   TByte, 0, 127   # -64 .. +63

  controls:
    0 source    TEnum, mfx_control_source_values
    1 sens      TByte, 1, 127
  control:
    repeat(4,2) controls
    8 assign:
      repeat(4,1) TByte, 0, 16

  mfx:
    0x00 type               TByte, 0, 80
    0x01 dry_send           TByte, 0, 127
    0x02 chorus_send        TByte, 0, 127
    0x03 reverb_send        TByte, 0, 127
    0x04 output_asssign     TEnum, fx_output_assign_values
    0x05 control:           control
    0x11 parameter:         parameters_32

  chorus:
    0x00 type               TByte, 0, 3
    0x01 level              TByte, 0, 127
    0x02 output_assign      TEnum, fx_output_assign_values
    0x03 output_select      TEnum, "MAIN REV MAIN+REV"
    0x04 parameter:         parameters_20

  reverb:
    0x00 type               TByte, 0, 5
    0x01 level              TByte, 0, 127
    0x02 output_assign      TEnum, fx_output_assign_values
    0x03 parameter:         parameters_20

  midi_n:
    rx:
      0x00   pc                 TBool
      0x01   bank               TBool
      0x02   bend               TBool
      0x03   key_pressure       TBool
      0x04   channel_pressure   TBool
      0x05   modulation         TBool
      0x06   volume             TBool
      0x07   pan                TBool
      0x08   expression         TBool
      0x09   hold_1             TBool
    0x0a   phase_lock           TBool
    0x0b   velocity_curve_type  TByte, 0, 4 # 0=OFF
  midis: repeat(16, 0x100) midi_n

  part_n:
    0x00 rx_channel           TNibble, 0, 15
    0x01 rx_switch            TBool
    0x02 reserved_1
    0x04 patch_bank_msb       TByte, 0, 127
    0x05 patch_bank_lsb       TByte, 0, 127
    0x06 patch_pc             TByte, 0, 127
    0x07 level                TByte, 0, 127
    0x08 pan                  TByte, 0, 127
    0x09 coarse_tune          TByte, 16, 112
    0x0a fine_tune            TByte, 14, 114
    0x0b mono_poly            TEnum, "MONO POLY PATCH"
    0x0c legato               TEnum, off_on_patch_values
    0x0d bend_range           TByte, 0, 25          # 25=PATCH
    0x0e portamento_switch    TEnum, off_on_patch_values
    0x0f portamento_time      TNibblePair, 0, 128   # 128=PATCH
    0x11 cutoff_offset        TByte, 0, 127         # -64 .. +63
    0x12 resonance_offset     TByte, 0, 127         # -64 .. +63
    0x13 attack_offset        TByte, 0, 127         # -64 .. +63
    0x14 release_offset       TByte, 0, 127         # -64 .. +63
    0x15 octave_shift         TByte, 61, 67         #  -3 .. +3
    0x16 velocity_sens_offset TByte, 1, 127         # -63 .. +63
    0x17 reserved_2
    0x1b mute   TBool
    0x1c dry_send             TByte, 0, 127
    0x1d chorus_send          TByte, 0, 127
    0x1e reverb_send          TByte, 0, 127
    0x1f output_assign        TEnum, output_assign_part_values
    0x20 output_mfx_select    TEnum, "MFX1 MFX2 MFX3"
    0x21 decay_offset         TByte, 0, 127         # -64 .. +63
    0x22 vibrato_rate         TByte, 0, 127         # -64 .. +63
    0x23 vibrato_depth        TByte, 0, 127         # -64 .. +63
    0x24 vibrato_delay        TByte, 0, 127         # -64 .. +63
    0x25 scale:               scale_map
  parts: repeat(16, 0x100) part_n

  zone_n:
    0x00 octave_shift   TByte, 61, 67               #  -3 .. +3
    0x01 switch         TBool
    0x02 reserved_1
    0x0c range_lower    TByte, 0, 127
    0x0d range_upper    TByte, 0, 127
    0x0e reserved_2
    0x1a reserved_3
  zones: repeat(16, 0x100) zone_n

  matrix_control:
    0 source            TEnum, matrix_control_source_values
    1 destination_1     TEnum, matrix_control_dest_values
    2 sens_1            TByte, 1, 127                       # -63 .. +63
    3 destination_2     TEnum, matrix_control_dest_values
    4 sens_2            TByte, 1, 127                       # -63 .. +63
    5 destination_3     TEnum, matrix_control_dest_values
    6 sens_3            TByte, 1, 127                       # -63 .. +63
    7 destination_4     TEnum, matrix_control_dest_values
    8 sens_4            TByte, 1, 127                       # -63 .. +63

  keyboard_ranges:
    0 range_lower   TByte, 0, 127
    1 range_upper   TByte, 0, 127
    2 fade_lower    TByte, 0, 127
    3 fade_upper    TByte, 0, 127

  velocity_ranges:
    0 range_lower   TByte, 1, 127
    1 range_upper   TByte, 1, 127
    2 fade_lower    TByte, 0, 127
    3 fade_upper    TByte, 0, 127

  tmt_n:
    0 tone_switch   TBool
    1 keyboard:     keyboard_ranges
    5 velocity:     velocity_ranges

  tmt:
    "1-2":
      0x00   structure_type     TByte, 0, 9
      0x01   booster            TEnum, booster_values
    "3-4":
      0x02   structure_type     TByte, 0, 9
      0x03   booster            TEnum, booster_values
    0x04     velocity_control   TEnum, "OFF  ON  RANDOM  CYCLE"
    0x05     1: tmt_n
    0x0e     2: tmt_n
    0x17     3: tmt_n
    0x20     4: tmt_n

  tone_control_switches:
    switch:
      repeat(4,1) TEnum, tone_control_switch_values

  patch_tone_n:
    0x0000   level              TByte, 0, 127
    0x0001   coarse_tune        TByte, 16, 112 # -48 .. +48
    0x0002   fine_tune          TByte, 14, 114 # -50 .. +50
    0x0003   random_pitch_depth TEnum, random_pitch_depth_values
    0x0004   pan                TByte, 0, 127
    0x0005   pan_keyfollow      TByte, 54, 74 # -100 .. +100
    0x0006   random_pan_depth   TByte, 0, 63
    0x0007   alt_pan_depth      TByte, 1, 127
    0x0008   env_sustain        TEnum, "NO-SUS  SUSTAIN"
    0x0009   delay_mode         TEnum, "NORMAL  HOLD  KEY-OFF-NORMAL  KEY-OFF-DECAY"
    0x000a   delay_time         TNibblePair, 0, 149 # 0 - 127, MUSICAL-NOTES
    0x000c   dry_send           TByte, 0, 127
    0x000d   chorus_send_mfx    TByte, 0, 127
    0x000e   reverb_send_mfx    TByte, 0, 127
    0x000f   chorus_send        TByte, 0, 127
    0x0010   reverb_send        TByte, 0, 127
    0x0011   output_assign      TEnum, output_assign_values
    rx:
      0x0012 bend               TBool
      0x0013 expression         TBool
      0x0014 hold_1             TBool
      0x0015 pan_mode           TEnum, pan_mode_values
      0x0016 redamper_switch    TBool
    control:
      0x0017 1:                 tone_control_switches
      0x001b 2:                 tone_control_switches
      0x001f 3:                 tone_control_switches
      0x0023 4:                 tone_control_switches
    0x0027   reserved
    wave:
      0x002c number_l           TNibbleQuad, 0, 16384 # 0=OFF
      0x0030 number_r           TNibbleQuad, 0, 16384 # 0=OFF
      0x0034 gain               TEnum, gain_values
      fxm:
        0x35 switch             TBool
        0x36 color              TByte, 0, 3
        0x37 depth              TByte, 0, 16
      0x0038 tempo_sync         TBool
      0x0039 pitch_keyfollow    TByte, 44, 84 # -200 .. +200
    pitch_env:
      0x003a depth              TByte, 52, 76 # -12 .. +12
      0x003b velocity_sens      TByte, 1, 127 # -63 .. +63
      time:
         0x3c "1_velocity_sens" TByte, 1, 127 # -63 .. +63
         0x3d "4_velocity_sens" TByte, 1, 127 # -63 .. +63
         0x3e keyfollow         TByte, 54, 74 # -100 .. +100
         0x3f 1                 TByte, 0, 127
         0x40 2                 TByte, 0, 127
         0x41 3                 TByte, 0, 127
         0x42 4                 TByte, 0, 127
      level:
         0x43 0                 TByte, 1, 127 # -63 .. +63
         0x44 1                 TByte, 1, 127 # -63 .. +63
         0x45 2                 TByte, 1, 127 # -63 .. +63
         0x46 3                 TByte, 1, 127 # -63 .. +63
         0x47 4                 TByte, 1, 127 # -63 .. +63
    tvf:
      0x0048 filter_type        TEnum, tvf_filter_types
      cutoff:
        0x0049 frequency        TByte, 0, 127
        0x004a keyfollow        TByte, 44, 84 # -200 .. +200
        0x004b velocity_curve   TNibble, 0, 7
        0x004c velocity_sens    TByte, 1, 127 # -63 .. +63
      resonance:
        0x004d q                TByte, 0, 127
        0x004e velocity_sens    TByte, 1, 127 # -63 .. +63
      env:
        0x004f depth            TByte, 1, 127 # -63 .. +63
        0x0050 velocity_curve   TByte, 0, 7
        0x0051 velocity_sens    TByte, 1, 127
        time:
           0x52 "1_velocity_sens" TByte, 1, 127
           0x53 "4_velocity_sens" TByte, 1, 127
           0x54 keyfollow       TByte, 54, 74 # -100 .. +100
           0x55 1               TByte, 0, 127
           0x56 2               TByte, 0, 127
           0x57 3               TByte, 0, 127
           0x58 4               TByte, 0, 127
        level:
           0x59 0               TByte, 0, 127
           0x5a 1               TByte, 0, 127
           0x5b 2               TByte, 0, 127
           0x5c 3               TByte, 0, 127
           0x5d 4               TByte, 0, 127
    tva:
      bias:
        0x5e level              TByte, 54, 74 # -100 .. +100
        0x5f position           TByte, 0, 127
        0x60 direction          TEnum, "LOWER  UPPER  LOWER&UPPER  ALL"
      level:
        0x61 velocity_curve     TByte, 0, 7
        0x62 velocity_sens      TByte, 1, 127
      env:
        time:
           0x63 "1_velocity_sen s" TByte, 1, 127
           0x64 "4_velocity_sen s" TByte, 1, 127
           0x65 keyfollow        TByte, 54, 74 # -100 .. +100
           0x66 1                TByte, 0, 127
           0x67 2                TByte, 0, 127
           0x68 3                TByte, 0, 127
           0x69 4                TByte, 0, 127
        level:
           0x6a 1                TByte, 0, 127
           0x6b 2                TByte, 0, 127
           0x6c 3                TByte, 0, 127
    lfo:
      1:
        0x006d waveform        TEnum, lfo_waveform_values
        0x006e rate            TNibblePair, 0, 149 # 0 .. 127, MUSICAL-NOTES
        0x0070 offset          TEnum, lfo_offset_values
        0x0071 rate_detune     TByte, 0, 127
        delay:
          0x072  time          TByte, 0, 127
          0x073  key_follow    TByte, 54, 74 # -100 .. +100
        fade:
          0x074  mode          TEnum, lfo_fade_mode_values
          0x075  time          TByte, 0, 127
        0x0076 key_trigger     TBool
        0x0077 pitch_depth     TByte, 1, 127 # -63 .. +63
        0x0078 tvf_depth       TByte, 1, 127 # -63 .. +63
        0x0079 tva_depth       TByte, 1, 127 # -63 .. +63
        0x007a pan_depth       TByte, 1, 127 # -63 .. +63
      2:
        0x007b waveform        TEnum, lfo_waveform_values
        0x007c rate            TNibblePair, 0, 149 # 0 .. 127, MUSICAL-NOTES
        0x007e offset          TEnum, lfo_offset_values
        0x007f rate_detune     TByte, 0, 127
        delay:
          0x100  time          TByte, 0, 127
          0x101  key_follow    TByte, 54, 74 # -100 .. +100
        fade:
          0x102  mode          TEnum, lfo_fade_mode_values
          0x103  time          TByte, 0, 127
        0x0104 key_trigger     TBool
        0x0105 pitch_depth     TByte, 1, 127 # -63 .. +63
        0x0106 tvf_depth       TByte, 1, 127 # -63 .. +63
        0x0107 tva_depth       TByte, 1, 127 # -63 .. +63
        0x0108 pan_depth       TByte, 1, 127 # -63 .. +63
      step:
        0x0109 type            TByte, 0, 1
        0x010a   1             TByte, 28, 100 # -36 .. +36
        0x010b   2             TByte, 28, 100 # -36 .. +36
        0x010c   3             TByte, 28, 100 # -36 .. +36
        0x010d   4             TByte, 28, 100 # -36 .. +36
        0x010e   5             TByte, 28, 100 # -36 .. +36
        0x010f   6             TByte, 28, 100 # -36 .. +36
        0x0110   7             TByte, 28, 100 # -36 .. +36
        0x0111   8             TByte, 28, 100 # -36 .. +36
        0x0112   9             TByte, 28, 100 # -36 .. +36
        0x0113  10             TByte, 28, 100 # -36 .. +36
        0x0114  11             TByte, 28, 100 # -36 .. +36
        0x0115  12             TByte, 28, 100 # -36 .. +36
        0x0116  13             TByte, 28, 100 # -36 .. +36
        0x0117  14             TByte, 28, 100 # -36 .. +36
        0x0118  15             TByte, 28, 100 # -36 .. +36
        0x0119  16             TByte, 28, 100 # -36 .. +36

  performance_controller:
    0x00 reserved_1
    0x18 arp_zone_number       TByte, 0, 15
    0x19 reserved_1
    0x54 recommended_tempo     TNibblePair, 20, 250
    0x56 reserved_2
    0x59 reserved_3

  performance_pattern:
    common:
      0x00 name                  TName
      0x0c solo                  TBool
      0x0d mfx1_channel          TByte, 0, 16 # 16=OFF
      0x0e reserved_1
      0x0f reserved_2
      0x10 voice_reserve:        voice_reserves
      0x20 reserved_3
      0x30 mfx1_source           TEnum, source_values
      0x31 mfx2_source           TEnum, source_values
      0x32 mfx3_source           TEnum, source_values
      0x33 chorus_source         TEnum, source_values
      0x34 reverb_source         TEnum, source_values
      0x35 mfx2_channel          TByte, 0, 16
      0x36 mfx3_channel          TByte, 0, 16
      0x37 mfx_structure         TByte, 0, 15
    0x0200 mfx1:                 mfx
    0x0400 chorus:               chorus
    0x0600 reverb:               reverb
    0x0800 mfx2:                 mfx
    0x0a00 mfx3:                 mfx
    0x1000 midi:                 midis
    0x2000 part:                 parts
    0x5000 zone:                 zones
    0x6000 controller:           performance_controller
  performance_patterns: repeat(128, 0x010000) performance_pattern

  pad:
    0 velocity         TByte, 1, 127
    2 pattern_number   TNibblePair, 0, 255
  pads: repeat(8, 2) pad

  patch:
    common:
      0x00      name               TName
      0x0c      category           TByte, 0, 127
      0x0d      reserved_1
      0x0e      level              TByte, 0, 127
      0x0f      pan                TByte, 0, 127
      0x10      priority           TEnum, "LAST  LOUDEST"
      0x11      coarse_tune        TByte, 16, 112 # -48 .. +48
      0x12      fine_tune          TByte, 14, 114 # -50 .. +50
      0x13      octave_shift       TByte, 61, 67               #  -3 .. +3
      0x14      stretch_tune_depth TByte, 0, 3
      0x15      analog_feel        TByte, 0, 127
      0x16      mono_poly          TBool
      0x17      legato_switch      TBool
      0x18      legato_retrigger   TBool
      portamento:
        0x19    switch             TBool
        0x1a    mode               TEnum, "NORMAL LEGATO"
        0x1b    type               TEnum, "RATE   TIME"
        0x1c    start              TEnum, "PITCH  NOTE"
        0x1d    time               TByte, 0, 127
      0x1e      reserved_2
      0x22      cutoff_offset      TByte, 1, 127  # -63 .. +63
      0x23      resonance_offset   TByte, 1, 127  # -63 .. +63
      0x24      attack_offset      TByte, 1, 127  # -63 .. +63
      0x25      release_offset     TByte, 1, 127  # -63 .. +63
      0x26      velocity_offset    TByte, 1, 127  # -63 .. +63
      0x27      output_assign      TEnum, output_assign_tone_values
      0x28      tmt_control_switch TBool
      0x29      bend_range_up      TByte, 0, 48
      0x2a      bend_range_down    TByte, 0, 48
      matrix_control:
        0x2b    1:                 matrix_control
        0x34    2:                 matrix_control
        0x3d    3:                 matrix_control
        0x46    4:                 matrix_control
      0x4f      modulation_switch  TBool
      0x000200  mfx:               mfx
      0x000400  chorus:            chorus
      0x000600  reverb:            reverb
    0x001000    tmt:               tmt
    tone:
      0x002000  1:                 patch_tone_n
      0x002200  2:                 patch_tone_n
      0x002400  3:                 patch_tone_n
      0x002600  4:                 patch_tone_n
  performance_patches: repeat(256, 0x10000) patch

  drum_wmt_n:
    wave:
      0x00    switch              TBool
      0x01    reserved
      0x06    number_l            TNibbleQuad, 0, 16384 # 0=OFF
      0x0a    number_r            TNibbleQuad, 0, 16384 # 0=OFF
      0x0e    gain                TEnum, gain_values
      fxm:
        0x0f  switch              TBool
        0x10  color               TByte, 0, 3
        0x11  depth               TByte, 0, 16
      0x12    tempo_sync          TBool
      0x13    coarse_tune         TByte, 16, 112 # -48 .. +48
      0x14    fine_tune           TByte, 14, 114 # -50 .. +50
      0x15    pan                 TByte, 0, 127
      0x16    random_pan_switch   TBool
      0x17    alt_pan_switch      TEnum, "OFF  ON  REVERSE"
      0x18    level               TByte, 0, 127
    0x19      velocity:           velocity_ranges

  drum_tone_n:
    0x00    name                      TName
    0x0c    assign_single             TBool
    0x0d    mute_group                TByte, 0, 31 # 0=OFF
    0x0e    level                     TByte, 0, 127
    0x0f    coarse_tune               TByte, 0, 127
    0x10    fine_tune                 TByte, 14, 114 # -50 .. +50
    0x11    random_pitch_depth        TEnum, random_pitch_depth_values
    0x12    pan                       TByte, 0, 127
    0x13    random_pan_depth          TByte, 0, 63
    0x14    alt_pan_depth             TByte, 1, 127
    0x15    env_sustain               TByte, 0, 127
    0x16    dry_send                  TByte, 0, 127
    0x17    chorus_send               TByte, 0, 127
    0x18    reverb_send               TByte, 0, 127
    0x19    chorus_send               TByte, 0, 127
    0x1a    reverb_send               TByte, 0, 127
    0x1b    output_assign             TEnum, output_assign_values
    0x1c    bend_range                TByte, 0, 48
    rx:
      0x1d  expression                TBool
      0x1e  hold_1                    TBool
      0x1f  pan_mode                  TEnum, pan_mode_values
    wmt:
      0x20  velocity_control          TEnum, "OFF  ON  RANDOM"
      0x21  1:                        drum_wmt_n
      0x3e  2:                        drum_wmt_n
      0x5b  3:                        drum_wmt_n
      0x78  4:                        drum_wmt_n
    pitch_env:
      0x115 depth                     TByte, 52, 76 # -12 .. +12
      0x116 velocity_sens             TByte, 1, 127 # -63 .. +63
      time:
        0x117 "1_velocity_sens"       TByte, 1, 127 # -63 .. +63
        0x118 "4_velocity_sens"       TByte, 1, 127 # -63 .. +63
        0x119 1                       TByte, 0, 127
        0x11a 2                       TByte, 0, 127
        0x11b 3                       TByte, 0, 127
        0x11c 4                       TByte, 0, 127
      level:
        0x11d 0                       TByte, 1, 127 # -63 .. +63
        0x11e 1                       TByte, 1, 127 # -63 .. +63
        0x11f 2                       TByte, 1, 127 # -63 .. +63
        0x120 3                       TByte, 1, 127 # -63 .. +63
        0x121 4                       TByte, 1, 127 # -63 .. +63
    tvf:
      0x122   filter_type             TEnum, tvf_filter_types
      cutoff:
        0x123 frequency               TByte, 0, 127
        0x124 velocity_curve          TNibble, 0, 7
        0x125 velocity_sens           TByte, 1, 127 # -63 .. +63
      resonance:
        0x126 q                       TByte, 0, 127
        0x127 velocity_sens           TByte, 1, 127 # -63 .. +63
      env:
        0x128 depth                   TByte, 1, 127 # -63 .. +63
        0x129 velocity_curve          TByte, 0, 7
        0x12a velocity_sens           TByte, 1, 127
        time:
          0x12b "1_velocity_sens"     TByte, 1, 127 # -63 .. +63
          0x12c "4_velocity_sens"     TByte, 1, 127 # -63 .. +63
          0x12d 1                     TByte, 0, 127
          0x12e 2                     TByte, 0, 127
          0x12f 3                     TByte, 0, 127
          0x130 4                     TByte, 0, 127
        level:
          0x131 0                     TByte, 0, 127
          0x132 1                     TByte, 0, 127
          0x133 2                     TByte, 0, 127
          0x134 3                     TByte, 0, 127
          0x135 4                     TByte, 0, 127
    tva:
      level:
        0x136 velocity_curve          TByte, 0, 7
        0x137 velocity_sens           TByte, 1, 127
      env:
        time:
          0x138 "1_velocity_sens"     TByte, 1, 127
          0x139 "4_velocity_sens"     TByte, 1, 127
          0x13a 1                     TByte, 0, 127
          0x13b 2                     TByte, 0, 127
          0x13c 3                     TByte, 0, 127
          0x13d 4                     TByte, 0, 127
        level:
          0x13e 1                     TByte, 0, 127
          0x13f 2                     TByte, 0, 127
          0x140 3                     TByte, 0, 127
    0x141 one_shot_mode               TBool
    0x142 relative_level              TByte, 0, 127

  drum_kit:
    common:
      0x00   name            TName
      0x0c   level           TByte, 0, 127
      0x0d   reserved
      0x11   output_assign   TEnum, output_assign_tone_values
    0x000200 mfx:            mfx
    0x000400 chorus:         chorus
    0x000600 reverb:         reverb
    0x001000 tone:           repeat(21..108, 0x200) drum_tone_n

  patch_drum:
    0x00000000 patch: patch
    0x00100000 drum:  drum_kit

  arpeggio_pattern:
    0x0000 original_note  TByte, 0, 127
    step:                 repeat(32,2) TNibblePair, 0, 128
  arpeggio:
    0x0000 end_step      TByte, 1, 32
    0x0002 name          TName16
    0x0012 reserved
    0x1000 pattern_note: repeat(16, 0x100) arpeggio_pattern

  rhythm_group:
    0x00 name          TName16
    0x10 bank_msb      TByte, 0, 127
    0x11 bank_lsb      TByte, 0, 127
    0x12 pc            TByte, 0, 127
    0x13 reserved_1
    0x15 pad:          pads
    0x71 reserved_2
    0x72 reserved_3

  vocal_effect:
    0x00 name          TName
    0x0c type          TEnum, "Vocoder  Auto-Pitch"
    0x0d reserved_1
    0x0e bank_msb      TByte, 0, 127
    0x0f bank_lsb      TByte, 0, 127
    0x10 pc            TByte, 0, 127
    0x11 level         TByte, 0, 127
    0x12 pan           TByte, 0, 127
    0x13 reserved_2
    auto_pitch:
      0x16 type        TEnum, "SOFT  HARD  ELECTRIC1  ELECTRIC2  ROBOT"
      0x17 scale       TEnum, "CHROMATIC Maj(Min)"
      0x18 key         TEnum, auto_pitch_key_values
      0x19 note        TEnum, auto_pitch_note_values
      0x1a gender      TByte, 0, 20 # -10 .. +10
      0x1b octave      TByte, 0, 2  # -1 .. +1
      0x1c balance     TByte, 0, 100
    vocoder:
      0x1d envelope    TEnum, "SHARP  SOFT  LONG"
      0x1e mic_sens    TByte, 0, 127
      0x1f synth_level TByte, 0, 127
      0x20 mic_mix     TByte, 0, 127
      0x21 mic_hpf     TEnum, "BYPASS  1000  1250  1600  2000  2500  3150  4000  5000  6300  8000  10000  12500  16000"
    0x22 part_level    TByte, 0, 127
  vocal_effects: repeat(20, 0x100) vocal_effect

  setup:
    0x00 sound_mode         TEnum, "PATCH  PERFORM  GM1  GM2  GS"
    performance:
      0x01 bank_msb         TByte, 0, 127
      0x02 bank_lsb         TByte, 0, 127
      0x03 pc               TByte, 0, 127
    kbd_patch:
      0x04 bank_msb         TByte, 0, 127
      0x06 bank_lsb         TByte, 0, 127
      0x07 pc               TByte, 0, 127
    rhy_patch:
      0x07 bank_msb         TByte, 0, 127
      0x08 bank_lsb         TByte, 0, 127
      0x09 pc               TByte, 0, 127
    0x0a mfx1_switch        TBool
    0x0b mfx2_switch        TBool
    0x0c mfx3_switch        TBool
    0x0d chorus_switch      TBool
    0x0e reverb_switch      TBool
    0x0f reserved_1
    0x12 transpose          TByte, 59, 70   # -5 .. +6
    0x13 octave_shift       TByte, 61, 67   # -3 .. +3
    0x14 reserved_4
    0x15 knob_select        TByte, 0, 2
    0x16 reserved_5
    arpeggio:
      0x17 grid             TEnum, "04_  08_  08L  08H  08t  16_  16L  16H  16t"
      0x18 duration         TEnum, "30  40  50  60  70  80  90  100  120  FUL"
      0x19 switch           TBool
      0x1a reserved_6
      0x1b style            TByte, 0, 127
      0x1c motif            TEnum, "UP/L  UP/H  UP/_  dn/L  dn/H  dn/_  Ud/L  Ud/H  Ud/_  rn/L"
      0x1d octave_range     TByte, 61, 67   # -3 .. +3
      0x1e hold             TBool
      0x1f accent           TByte, 0, 100
      0x20 velocity         TByte, 0, 127
    rhythm:
      0x21 switch           TBool
      0x22 reserved_7
      0x23 style            TNibblePair, 0, 255
      0x25 reserved_8
      0x26 group            TByte, 0, 29
      0x27 accent           TByte, 0, 100
      0x28 velocity         TByte, 1, 127
      0x29 reserved_9
    0x33 arpeggio_step      TByte, 0, 32

  system_controller:
    tx:
      0x00 pc               TBool
      0x01 bank             TBool
    0x02 velocity           TByte, 0, 127 # 0=REAL
    0x03 velocity_curve     TEnum, "LIGHT   MEDIUM   HEAVY"
    0x04 reserved_1
    0x05 hold_polarity      TEnum, polarity
    0x06 continuous_hold    TBool
    control_pedal:
      0x07 assign           TEnum, pedal_assign_values
      0x08 polarity         TEnum, polarity
    0x09 reserved_2
    knob_assign:
      0x10 1                TEnum, knob_assign_values
      0x11 2                TEnum, knob_assign_values
      0x12 3                TEnum, knob_assign_values
      0x13 4                TEnum, knob_assign_values
    0x14 reserved_2
    0x4d reserved_3

  system:
    common:
      master:
        0x00 tune             TNibbleQuad, 24, 2024 # -100 .. +100
        0x04 key_shift        TByte, 40, 88    #  -24 .. +24
        0x05 level            TByte, 0, 127
      0x06 scale_switch       TBool
      0x07 patch_remain       TBool
      0x08 mix_parallel       TBool
      0x09 control_channel    TByte, 0, 16 # 16=OFF
      0x0a kbd_patch_channel  TByte, 0, 15
      0x0b reserved_1
      0x0c scale:             scale_map
      control_source:
        0x18 1                TEnum, control_source_values
        0x19 2                TEnum, control_source_values
        0x1a 3                TEnum, control_source_values
        0x1b 4                TEnum, control_source_values
      rx:
        0x1c pc               TBool
        0x1d bank             TBool
    0x004000 controller:      system_controller

  patch_parts:
    0x000000 x1: patch_drum       # patch mode part 1
    0x200000 x2: patch_drum

  juno:
    0x01000000       setup:               setup
    0x02000000       system:              system
    temporary:
      0x10000000     performance_pattern: performance_pattern
      performance_part:
        0x11000000   1:                   patch_drum # Temporary Patch/Drum (Performance Mode Part 1)
        0x11200000   2:                   patch_drum
        0x11400000   3:                   patch_drum
        0x11600000   4:                   patch_drum
        0x12000000   5:                   patch_drum
        0x12200000   6:                   patch_drum
        0x12400000   7:                   patch_drum
        0x12600000   8:                   patch_drum
        0x13000000   9:                   patch_drum
        0x13200000  10:                   patch_drum
        0x13400000  11:                   patch_drum
        0x13600000  12:                   patch_drum
        0x14000000  13:                   patch_drum
        0x14200000  14:                   patch_drum
        0x14400000  15:                   patch_drum
        0x14600000  16:                   patch_drum
      0x1e000000    rhythm_pattern:       arpeggio
      0x1e110000    arpeggio:             arpeggio
      0x1e130000    rhythm_group:         rhythm_group
      0x1e150000    vocal_effect:         vocal_effect
      0x1f000000    patch_part:           patch_parts
    user:
      0x20000000    performance:          performance_patterns
      0x21000000    pattern:              performance_patterns
      0x30000000    patch:                performance_patches
      0x40000000    drum_kit:             repeat(8, 0x100000) drum_kit
      0x60000000    vocal_effect:         vocal_effects
  juno_map:
    0 juno: juno

{.compile: "cmap.c".}

type
  AddrT   {.importc: "capmix_addr_t", header: "cmap.h".} = JAddr
  Adapter {.importc: "capmix_mem_t", header: "cmap.h".} = object
    offset*: AddrT
    name: cstring
    kind*: Kind
    low*, high*: cint
    values*: cstringArray
    area*: ptr UncheckedArray[ptr Adapter]
  AdapterArray* = ptr UncheckedArray[ptr Adapter]
  Mem* = ptr Adapter
  MemArea* = AdapterArray

let ENDA = 0xffffffff.AddrT

iterator items*(area: AdapterArray): ptr Adapter =
  if area.ptr != nil:
    var n = 0
    while area[n][].offset != ENDA:
      yield area[n]
      inc n

let top_area* {.importc.}: AdapterArray
let juno_map* = top_area[0]

#type
#  MemObj* = object # tree structure for describing areas of device memory
#    offset*: JAddr
#    case kind*: Kind
#    of TEnum:
#      values*: EnumList
#    of TByte, TNibble, TNibblePair, TNibbleQuad:
#      low*, high*: int
#    else:
#      discard
#    name*:   string
#    area*:  seq[Mem]
#  Mem* = ref MemObj
#  MemArea* = seq[Mem]

proc `$`*(mem: Mem): string =
  result &= $mem.offset
  if mem.offset != NOFF:
    result &= " "
  result &= mem.name
  if mem.kind != TNone:
    result &= "\t" & $mem.kind
    case mem.kind
    of TByte, TNibble, TNibblePair, TNibbleQuad:
      result &= ", " & $mem.low & ", " & $mem.high
    of TEnum:
      discard
      #result &= ", " & $mem.values
    else:
      discard
  else:
    result &= ":"

proc value*(mem: Mem, b: seq[byte]): int =
  result = mem.kind.value(b)

proc len*(area: MemArea): int =
  for mem in area:
    result += 1

proc name*(mem: Mem): string = $mem.name
