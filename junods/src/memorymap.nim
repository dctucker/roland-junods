import strutils
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

type
  Mem* = ref object # tree structure for describing areas of device memory
    offset*: JAddr
    case kind*: Kind
    of TEnum:
      values*: EnumList
    of TByte, TNibble, TNibblePair, TNibbleQuad:
      low*, high*: int
    else:
      discard
    name*:   string
    area*:  seq[Mem]
  MemArea* = seq[Mem]

proc format(mem: Mem, level: int): string =
  if level > 1: return ""
  for m in mem.area:
    result &= indent( m.format(level), level*4 )

proc `$`*(mem: Mem): string=
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
      result &= ", " & $mem.values
    else:
      discard
  else:
    result &= ":"

proc value*(mem: Mem, b: seq[byte]): int =
  result = mem.kind.value(b)

macro repeat(thing: MemArea, n, span: static[int]): seq[Mem] =
  result = quote do: @[]
  for i in 0..<n:
    let name = newStrLitNode $(i + 1)
    let offset = newIntLitNode(span * i)
    let offset_node = quote do: `offset`.JAddr
    result[^1].add quote do:
      Mem( offset: `offset`.JAddr, name: `name`, area: `thing`)

macro repeat(thing: Mem, n, span: static[int]): seq[Mem] =
  result = quote do: @[]

  for i in 0..<n:
    let node = thing.copy()
    let offset = newIntLitNode(span * i)
    let offset_node = quote do: `offset`.JAddr
    node.add newColonExpr( ident("name"), newStrLitNode($(i + 1)) )
    node.add newColonExpr( ident("offset"), offset_node )
    result[^1].add node

macro repeat(kind: Kind, n, span: static[int]): seq[Mem] =
  result = quote do: @[]
  for i in 0..<n:
    let name = newStrLitNode $(i + 1)
    let offset = newIntLitNode(span * i)
    result.add quote do: Mem( offset: `offset`.JAddr, name: `name`, kind: `kind`)



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

#proc get_all_command_ids(cmd: NimNode): seq[string] {.compileTime.} =
#  result = @[]
#  for id in cmd:
#    case id.kind
#    of nnkCommand, nnkPrefix:
#      for id2 in get_all_command_ids(id):
#        result.add id2
#    of nnkIdent, nnkStrLit:
#      result.add id.id_string()
#    of nnkIntLit:
#      result.add $id.intVal()
#    of nnkTripleStrLit:
#      for str in id.strVal().splitWhitespace():
#        result.add str
#    else:
#      unrecognized "word id = " & $id.kind

#macro words(stmts: untyped): untyped =
#  #echo "input words = " & stmts.treeRepr
#  result = quote do:
#    @[]
#  for word in get_all_command_ids(stmts):
#    result[^1].add newLit(word)
#  return quote do:
#    EnumList( strings: `result` )
#  #echo "output words = " & result.treeRepr

proc diveMap(input: NimNode): seq[NimNode] {.compileTime.} =
  result = @[]
  #echo input.kind
  case input.kind
  of nnkStmtList:
    if input.len() == 1 and input[0].kind == nnkStmtList:
      result.add input[0]
    else:
      for stmt in input:
        for s in diveMap(stmt):
          result.add s
  of nnkCommand:
    var offset: BiggestInt = -1
    if input[0].kind == nnkIntLit:
      offset = input[0].intVal()
    let name = case input[1].kind
    of nnkIntLit:
      $input[1].intVal()
    of nnkStrLit, nnkIdent:
      input[1].strVal()
    of nnkCommand:
      case input[1][0].kind
      of nnkIntLit:
        $input[1][0].intVal()
      of nnkStrLit, nnkIdent:
        input[1][0].strVal()
      else:
        unrecognized "id = " & input[1].treeRepr
        ""
    else:
      unrecognized "id = " & input[1].treeRepr
      ""

    if input[1].kind == nnkCommand:
      let kind_str = input[1][1].strVal()
      let kind = kind_str.ident
      case kind_str
      of "TNibbleQuad","TNibblePair","TNibble","TByte":
        input.expectLen(4)
        let low  = input[2]
        let high = input[3]
        result.add quote do:
          Mem( offset: JAddr(`offset`), name: `name`, kind: `kind`, low: `low`, high: `high` )
      of "TEnum":
        case input[2].kind
        of nnkPrefix, nnkCall, nnkIdent:
          let values = input[2]
          if values.kind == nnkIdent:
            result.add quote do:
              Mem( offset: JAddr(`offset`), name: `name`, kind: `kind`, values: `values` )
          else:
            result.add quote do:
              Mem( offset: JAddr(`offset`), name: `name`, kind: `kind`, values: EnumList(strings: `values`) )
        #of nnkStmtList:
        #  let values = quote do:
        #    @[]
        #  for word in get_all_command_ids(input[2]):
        #    values[^1].add newLit(word)
        #  result.add quote do:
        #    Mem( offset: JAddr(`offset`), name: `name`, kind: `kind`, values: `values` )
        of nnkStrLit, nnkTripleStrLit:
          let values = quote do:
            @[]
          for word in input[2].strVal().splitWhitespace():
            values[^1].add newLit(word)
          result.add quote do:
            Mem( offset: JAddr(`offset`), name: `name`, kind: `kind`, values: EnumList(strings: `values`) )
        else:
          unrecognized "TEnum values = " & input[2].treeRepr
      of "TBool", "TName", "TName16":
        result.add quote do:
          Mem( offset: JAddr(`offset`), name: `name`, kind: `kind` )
      else:
        #let area = input[1][1]
        #result.add quote do:
        #  Mem( offset: JAddr(`offset`), name: `name`, area: `area` )
        unrecognized "mem = " & kind.treeRepr

    elif input.len() >= 3:
      for area in diveMap(input[2]):
        #echo "area = " , area.treeRepr
        case area.kind
        of nnkBracket:
          result.add quote do:
            Mem( offset: JAddr(`offset`), name: `name`, area: @`area`)
        of nnkIdent, nnkPrefix:
          result.add quote do:
            Mem( offset: JAddr(`offset`), name: `name`, area: `area`)
        of nnkObjConstr:
          result.add quote do:
            Mem( offset: JAddr(`offset`), name: `name`, area: @[`area`])
        else:
          echo "unexpected kind = " & area.treeRepr
    else:
      if not name.contains("reserved"):
        result.add quote do:
          Mem( offset: JAddr(`offset`), name: `name`)
    #echo "name = " & name.repr
  of nnkCall:
    let name = newLit input[0].id_string()
    result.add quote do:
      Mem( offset: NOFF, name: `name`, area: @[])
    input[0].expectKind {nnkIdent, nnkStrLit, nnkIntLit}
    for stmtlist in diveMap(input[1]):
      case stmtlist.kind
      of nnkBracket:
        for stmt in stmtlist:
          result[^1][^1][^1][^1].add(stmt)
      of nnkIdent:
        result[^1][^1][^1] = stmtlist
      of nnkObjConstr:
        result[^1][^1][^1][^1].add(stmtlist)
      else:
        echo "stmtlist kind = " & $stmtlist.kind
        result[^1][^1][^1][^1].add(stmtlist)
  of nnkIdent:
    result.add input
  else:
    result.add quote do:
      `input`

macro genMap(statement: untyped): untyped =
  #echo "input ast = " & statement.treeRepr
  var bracket = quote do:
    []
  for sub in statement:
    for dive in diveMap(sub):
      if dive.kind == nnkBracket:
        for d in dive:
          bracket.add d
      else:
        bracket.add dive
  result = quote do:
    @`bracket`
  #echo "output ast = " & result.treeRepr
  #echo result.repr




### map definitions

let voice_reserves = Mem(kind: TByte      , low:     0, high:    64).repeat(16, 1)
let parameters_20  = Mem(kind: TNibbleQuad, low: 12768, high: 52768).repeat(20, 4)
let parameters_32  = Mem(kind: TNibbleQuad, low: 12768, high: 52768).repeat(32, 4)

let scale_map = genMap:
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

let controls = genMap:
  0 source    TEnum, mfx_control_source_values
  1 sens      TByte, 1, 127
let assigns = Mem(kind: TByte, low: 0, high: 16).repeat(4,1)
let assign = genMap:
  8 assign: assigns
let control = controls.repeat(4,2) & assign

let mfx = genMap:
  0x00 type               TByte, 0, 80
  0x01 dry_send           TByte, 0, 127
  0x02 chorus_send        TByte, 0, 127
  0x03 reverb_send        TByte, 0, 127
  0x04 output_asssign     TEnum, fx_output_assign_values
  0x05 control:           control
  0x11 parameter:         parameters_32

let chorus = genMap:
  0x00 type               TByte, 0, 3
  0x01 level              TByte, 0, 127
  0x02 output_assign      TEnum, fx_output_assign_values
  0x03 output_select      TEnum, "MAIN REV MAIN+REV"
  0x04 parameter:         parameters_20

let reverb = genMap:
  0x00 type               TByte, 0, 5
  0x01 level              TByte, 0, 127
  0x02 output_assign      TEnum, fx_output_assign_values
  0x03 parameter:         parameters_20

let midi_n = genMap:
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
let midis = midi_n.repeat(16, 0x100)

let part_n = genMap:
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
let parts = part_n.repeat(16, 0x100)

let zone_n = genMap:
  0x00 octave_shift   TByte, 61, 67               #  -3 .. +3
  0x01 switch         TBool
  0x02 reserved_1
  0x0c range_lower    TByte, 0, 127
  0x0d range_upper    TByte, 0, 127
  0x0e reserved_2
  0x1a reserved_3
let zones = zone_n.repeat(16, 0x100)

let matrix_control = genMap:
  0 source            TEnum, matrix_control_source_values
  1 destination_1     TEnum, matrix_control_dest_values
  2 sens_1            TByte, 1, 127                       # -63 .. +63
  3 destination_2     TEnum, matrix_control_dest_values
  4 sens_2            TByte, 1, 127                       # -63 .. +63
  5 destination_3     TEnum, matrix_control_dest_values
  6 sens_3            TByte, 1, 127                       # -63 .. +63
  7 destination_4     TEnum, matrix_control_dest_values
  8 sens_4            TByte, 1, 127                       # -63 .. +63

let keyboard_ranges = genMap:
  0 range_lower   TByte, 0, 127
  1 range_upper   TByte, 0, 127
  2 fade_lower    TByte, 0, 127
  3 fade_upper    TByte, 0, 127

let velocity_ranges = genMap:
  0 range_lower   TByte, 1, 127
  1 range_upper   TByte, 1, 127
  2 fade_lower    TByte, 0, 127
  3 fade_upper    TByte, 0, 127

let tmt_n = genMap:
  0 tone_switch   TBool
  1 keyboard:     keyboard_ranges
  5 velocity:     velocity_ranges

let tmt = genMap:
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

let tone_control_switch = Mem(kind: TEnum, values: tone_control_switch_values).repeat(4, 1)
let tone_control_switches = genMap:
  switch: tone_control_switch

let patch_tone_n = genMap:
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

let performance_controller = genMap:
  0x00 reserved_1
  0x18 arp_zone_number       TByte, 0, 15
  0x19 reserved_1
  0x54 recommended_tempo     TNibblePair, 20, 250
  0x56 reserved_2
  0x59 reserved_3

let performance_pattern = genMap:
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
let performance_patterns = performance_pattern.repeat(128, 0x010000)

let pad = genMap:
  0 velocity         TByte, 1, 127
  2 pattern_number   TNibblePair, 0, 255
let pads = pad.repeat(8, 2)

let patch = genMap:
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
let performance_patches  = patch.repeat(256, 0x10000)

let drum_wmt_n = genMap:
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

let drum_tone_n = genMap:
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

proc generate_drum_tones(): MemArea =
  for i in 21..108:
    let k = 0x1000 + (0x200 * (i - 21))
    let a = ((k and 0x8000) shl 1) or (k and 0x7fff)
    result.add Mem( offset: JAddr(a), name: $i, area: drum_tone_n )
let drum_tones = generate_drum_tones()

let drum_kit = genMap:
  common:
    0x00   name            TName
    0x0c   level           TByte, 0, 127
    0x0d   reserved
    0x11   output_assign   TEnum, output_assign_tone_values
  0x000200 mfx:            mfx
  0x000400 chorus:         chorus
  0x000600 reverb:         reverb
  tone:                    drum_tones
let drum_kits = drum_kit.repeat(8, 0x100000)

let patch_drum = genMap:
  0x00000000 patch: patch
  0x00100000 drum:  drum_kit

let arpeggio_steps = Mem(kind: TNibblePair, low: 0, high: 128).repeat(32, 2)
let arpeggio_pattern = genMap:
  0x0000 original_note  TByte, 0, 127
  step:                 arpeggio_steps
let arpeggio_patterns = arpeggio_pattern.repeat(16, 0x100)
let arpeggio = genMap:
  0x0000 end_step      TByte, 1, 32
  0x0002 name          TName16
  0x0012 reserved
  0x1000 pattern_note: arpeggio_patterns

let rhythm_group = genMap:
  0x00 name          TName16
  0x10 bank_msb      TByte, 0, 127
  0x11 bank_lsb      TByte, 0, 127
  0x12 pc            TByte, 0, 127
  0x13 reserved_1
  0x15 pad:          pads
  0x71 reserved_2
  0x72 reserved_3

let vocal_effect = genMap:
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
let vocal_effects = vocal_effect.repeat(20, 0x100)

let setup = genMap:
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

let system_controller = genMap:
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

let system = genMap:
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

let patch_parts = genMap:
  0x000000 x1: patch_drum       # patch mode part 1
  0x200000 x2: patch_drum

let juno = genMap:
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
    0x40000000    drum_kit:             drum_kits
    0x60000000    vocal_effect:         vocal_effects
let juno_map* = Mem(area: juno)

