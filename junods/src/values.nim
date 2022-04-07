import system/io
import macros
import strutils
import sequtils

proc unrecognized(args: varargs[string]) {.compileTime.} =
  echo "unrecognized: ", args.join(" ")

type CArray = array[0..127, string]

type
  EnumList* = ref object
    strings*: seq[cstring]
    name: string

proc `&`*(a,b: EnumList): EnumList =
  return EnumList(name: a.name & "_" & b.name, strings: a.strings & b.strings)

proc `&`*(a: EnumList, b: string): EnumList =
  return EnumList(name: a.name & "_" & b.toLower, strings: a.strings & @[b.cstring])

proc `[]`*[I: Ordinal](a: EnumList, b: I): string =
  return $a.strings[b]

proc `$`*(e: EnumList): string =
  return e.name


import std/tables

proc generate_control_source_values(): seq[string] {.compileTime.} =
  result.add("OFF")
  for i in 1 .. 31:
    result.add("CC" & $i)
  for i in 33 .. 95:
    result.add("CC" & $i)
  result.add("BEND")
  result.add("AFT")
let control_sources {.compileTime.} = generate_control_source_values()


macro defEnums(body: untyped): untyped =
  var all = newTable[string, seq[string]]()
  result = newNimNode(nnkLetSection)
  for cmd in body:
    case cmd.kind
    of nnkCall:
      let name = postfix(cmd[0], "*")
      #let name = cmd[0]
      case cmd[1].kind
      of nnkStmtList:
        case cmd[1][0].kind
        of nnkStrLit, nnkTripleStrLit:
          let namestr = newStrLitNode(cmd[0].strVal())
          let strings = cmd[1][0].strVal().splitWhitespace()
          let enumlist = quote do:
            EnumList(name: `namestr`, strings: @`strings`)
          result.add newIdentDefs(name, newEmptyNode(), enumlist)
          all[cmd[0].strVal()] = strings
        else:
          unrecognized "defEnum = " & cmd.treeRepr
      else:
        unrecognized "defEnum = " & cmd.treeRepr
    of nnkAsgn:
      let name = postfix(cmd[0], "*")
      let namestr = newStrLitNode(cmd[0].strVal())
      let value = cmd[1]
      result.add newIdentDefs(name, newEmptyNode(), value)
      #echo "defEnum value = " & value.treeRepr
      case value.kind
      of nnkIdent:
        all[ cmd[0].strVal() ] = all[ cmd[1].strVal() ]
      of nnkObjConstr:
        all[ cmd[0].strVal() ] = @[] #value[^1][^1]
      of nnkInfix:
        case value[2].kind
        of nnkIdent:
          all[ cmd[0].strVal() ] = all[ value[1].strVal() ] & all[ value[2].strVal() ]
        of nnkStrLit:
          all[ cmd[0].strVal() ] = all[ value[1].strVal() ] & value[2].strVal()
        else:
          unrecognized "defEnum value = " & value.treeRepr
      else:
        unrecognized "defEnum value = " & value.treeRepr
      #all[cmd[0].strVal()] = value.static # https://forum.nim-lang.org/t/3038
    else:
      unrecognized "defEnum = " & cmd.treeRepr
  #echo result.treeRepr

  result = newNimNode(nnkLetSection)
  var c_lines: seq[string] = @[]
  for key,values in all.pairs():
    var str = "const char *" & key & "[] = { "
    str &= values.map(proc(x:string):string = "\"" & x & "\"").join(",")
    str &= " };"
    c_lines.add str

    let id = ident(key & "_a")
    let id_seq = ident(key)
    let namestr = newStrLitNode(key)
    let num = newIntLitNode(values.len())
    let letter = quote do:
      let
        `id`* {.importc: `namestr`, header: "values.c" .}: array[`num`, cstring]
        `id_seq`* = EnumList( name: `namestr`, strings: @`id` )
    for l in letter:
      result.add l

  "src/values.c".writeFile(c_lines.join("\n"))



defEnums:
  control_sources_enum_list = EnumList(name: "control_sources", strings: control_sources)
  control_source_values = control_sources_enum_list
  mfx_sys_values: """
    SYS1  SYS2  SYS3  SYS4
  """
  mfx_control_source_values = control_source_values & mfx_sys_values
  mfx_control_more_values: """
    VELOCITY
    KEYFOLLOW
    TEMPO
    LFO1
    LFO2
    PIT-ENV
    TVF-ENV
    TVA-ENV
  """
  matrix_control_source_values = mfx_control_source_values & mfx_control_more_values

  fx_output_assign_values: """
      A  ---  ---  ---
  """
  matrix_control_dest_values: """
    OFF   PCH   CUT   RES     LEV   PAN
    DRY   CHO   REV   PIT-LFO1
    PIT-LFO2  TVF-LFO1   TVF-LFO2
    TVA-LFO1  TVA-LFO2   PAN-LFO1
    PAN-LFO2  LFO1-RATE  LFO2-RATE
    PIT-ATK   PIT-DCY    PIT-REL
    TVF-ATK   TVF-DCY    TVF-REL
    TVA-ATK   TVA-DCY    TVA-REL
    TMT   FXM   FX1   MFX2    MFX3  MFX4
  """
  random_pitch_depth_values: """
    0 1  2    3    4    5    6    7    8    9
    10   20   30   40   50   60   70   80   90
    100  200  300  400  500  600  700  800  900
    1000 1100 1200
  """
  tvf_filter_types: """
    OFF LPF BPF HPF PKG LPF2 LPF
  """
  auto_pitch_key_values: """
    C   Db   D   Eb   E   F   F#   G   Ab   A   Bb   B
    Cm  C#m  Dm  D#m  Em  Fm  F#m  Gm  G#m  A   Bbm  Bm
  """
  auto_pitch_note_values: """
    C  C#  D  D#  E  F  F#  G  G#  A  A#  B
  """
  source_values: """
    PERFORM  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16
  """
  booster_values: """
    0  +6  +12  +18
  """
  gain_values: """
    -6  0  +6  +12
  """
  tone_control_switch_values: """
    OFF  ON  REVERSE
  """
  polarity: """
    STANDARD REVERSE
  """
  pedal_assign_values: """
    MODULATION  PORTA-TIME  VOLUME
    PAN  EXPRESSION
    HOLD  PORTAMENTO
    SOSTENUTO  RESONANCE
    RELEASE-TIME  ATTACK-TIME  CUTOFF
    DECAY-TIME  VIB-RATE  VIB-DEPTH
    VIB-DELAY  CHO-SEND-LEVEL
    REV-SEND-LEVEL  AFTERTOUCH
    START/STOP  TAP-TEMPO
    PROG-UP  PROG-DOWN
    FAV-UP  FAV-DOWN
  """
  control_source_more_values: """
    EQ-LOW-FREQ   EQ-LOW-GAIN
    EQ-MID-FREQ   EQ-MID-GAIN   EQ-MID-Q
    EQ-HIGH-FREQ  EQ-HIGH-GAIN
  """
  knob_assign_values = control_source_values & control_source_more_values
  lfo_waveform_values: """
    SIN  TRI  SAW-UP  SAW-DW  SQR  RND  BEND-UP  BEND-DN  TRP  S&H  CHS  VSIN  STEP
  """
  lfo_fade_mode_values: """
    ON-IN  ON-OUT  OFF-IN  OFF-OUT
  """
  lfo_offset_values: """
    -100  -50  0  +50  +100
  """
  pan_mode_values: """
    CONTINUOUS  KEY-ON
  """
  output_assign_values: """
    MFX  A  ---  ---  ---  1  2  ---  ---  ---  ---  ---  ---
  """
  output_assign_tone_values = output_assign_values & "TONE"
  output_assign_part_values = output_assign_values & "PART"
  off_on_patch_values: """
    OFF  ON  PATCH
  """

