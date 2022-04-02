import strutils
import memorymap
import macros

#dumpTree:
#  @[
#    Mem(offset: 0, name: "temporary"),
#    Mem(offset: 1, name: "performance", area: @[
#      Mem(offset: 10, name: "patch"),
#    ]),
#  ]

#dumpTree:
#  let mfx = @[
#    CM( 0x00, "type"       , TByte, 0, 80),
#    CM( 0x01, "dry_send"   , TByte, 0, 127),
#  ]


#dumpTree:
#  0x01000000 setup: setup
#  0x02000000 system: system
#  temporary:
#    0x10000000 performance_pattern: performance_pattern
#    0x11000000 performance_part:    performance_parts
#    0x1e000000 rhythm_pattern:      arpeggio
#    0x1e110000 arpeggio:            arpeggio
#    0x1e130000 rhythm_group:        rhythm_group
#    0x1e150000 vocal_effect:        vocal_effect
#    0x1f000000 patch_part: # patch mode part 1
#      0x000000 1: patch_drum
#      0x200000 2: patch_drum
#  user:
#    0x20000000 performance:  performance_patterns
#    0x21000000 pattern:      performance_patterns
#    0x30000000 patch:        performance_patches
#    0x40000000 drum_kit:     drum_kits
#    0x60000000 vocal_effect: vocal_effects

proc diveMap(input: NimNode): seq[NimNode] =
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
        echo "unrecognized id = " & input[1].treeRepr
        ""
    else:
      echo "unrecognized id = " & input[1].treeRepr
      ""

    if input[1].kind == nnkCommand:
      let kind_str = input[1][1].strVal()
      let kind = kind_str.ident
      case kind_str
      of "TNibbleQuad","TNibblePair","TNibble","TByte":
        let low  = input[2]
        let high = input[3]
        result.add quote do:
          Mem( offset: `offset`, name: `name`, kind: `kind`, low: `low`, high: `high` )
      of "TEnum":
        let values = input[2]
        result.add quote do:
          Mem( offset: `offset`, name: `name`, kind: `kind`, values: `values` )
      of "TBool":
        result.add quote do:
          Mem( offset: `offset`, name: `name`, kind: `kind` )
      else:
        echo "unrecognized mem kind = ", kind

    elif input.len() >= 3:
      for area in diveMap(input[2]):
        echo "area = " , area.treeRepr
        case area.kind
        of nnkBracket:
          result.add quote do:
            Mem( offset: `offset`, name: `name`, area: @`area`)
        of nnkIdent, nnkPrefix:
          result.add quote do:
            Mem( offset: `offset`, name: `name`, area: `area`)
        of nnkObjConstr:
          result.add quote do:
            Mem( offset: `offset`, name: `name`, area: @[`area`])
        else:
          echo "unexpected kind = " & area.treeRepr
    else:
      if not name.contains("reserved"):
        result.add quote do:
          Mem( offset: `offset`, name: `name`)
    #echo "name = " & name.repr
  of nnkCall:
    let name = newLit( $input[0].strVal() )
    result.add quote do:
      Mem( name: `name`, area: @[])
    input[0].expectKind(nnkIdent)
    for stmtlist in diveMap(input[1]):
      if stmtlist.kind == nnkBracket:
        for stmt in stmtlist:
          result[^1][^1][^1][^1].add(stmt)
      else:
        echo "stmtlist kind = " & $stmtlist.kind
        result[^1][^1][^1][^1].add(stmtlist)
  of nnkIdent:
    result.add input
  else:
    result.add quote do:
      `input`

macro genMap(statement: untyped): untyped =
  echo "input ast = " & statement.treeRepr
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
  echo "output ast = " & result.treeRepr
  echo result.repr





let scale_map = @[
  CM(0x00, "c" , TByte, 0, 127), # -64 .. +63
  CM(0x01, "c#", TByte, 0, 127), # -64 .. +63
  CM(0x02, "d" , TByte, 0, 127), # -64 .. +63
  CM(0x03, "d#", TByte, 0, 127), # -64 .. +63
  CM(0x04, "e" , TByte, 0, 127), # -64 .. +63
  CM(0x05, "f" , TByte, 0, 127), # -64 .. +63
  CM(0x06, "f#", TByte, 0, 127), # -64 .. +63
  CM(0x07, "g" , TByte, 0, 127), # -64 .. +63
  CM(0x08, "g#", TByte, 0, 127), # -64 .. +63
  CM(0x09, "a" , TByte, 0, 127), # -64 .. +63
  CM(0x0a, "a#", TByte, 0, 127), # -64 .. +63
  CM(0x0b, "b" , TByte, 0, 127), # -64 .. +63
]

let performance_patterns: MemArea = @[]
let performance_pattern: MemArea = @[]
let performance_parts: MemArea = @[]
let performance_patches: MemArea = @[]
let arpeggio: MemArea = @[]
let rhythm_group: MemArea = @[]
let vocal_effect: MemArea = @[]
let vocal_effects: MemArea = @[]
let patch_drum: MemArea = @[]
let drum_kits: MemArea = @[]

let setup = genMap: 0 common: @[]
let system = genMap:
  0x000000 common:
    0x0000 master:
      0x00 tune             TNibbleQuad, 24, 2024 # -100 .. +100
      0x04 key_shift        TByte, 40, 88    #  -24 .. +24
      0x05 level            TByte, 0, 127
    0x06 scale_switch       TBool
    0x07 patch_remain       TBool
    0x08 mix_parallel       TBool
    0x09 control_channel    TByte, 0, 16 # 16=OFF
    0x0a kbd_patch_channel  TByte, 0, 15
    0x0b reserved_1        TBool
    0x0c scale:             scale_map
    control_source:
      0x18 1                TEnum, control_source_values
      0x19 2                TEnum, control_source_values
      0x1a 3                TEnum, control_source_values
      0x1b 4                TEnum, control_source_values
    rx:
      0x1c pc               TBool
      0x1d bank             TBool
  0x004000 controller:
    tx:
      0x00 pc               TBool
      0x01 bank             TBool
    0x02 velocity           TByte, 0, 127 # 0=REAL
    0x03 velocity_curve     TEnum, @["LIGHT","MEDIUM","HEAVY"]
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

let juno_map = genMap:
  0x01000000 setup: setup
  0x02000000 system: system
  temporary:
    0x10000000 performance_pattern: performance_pattern
    performance_part:
      0x11000000   1: patch_drum # Temporary Patch/Drum (Performance Mode Part 1)
      0x11200000   2: patch_drum
      0x11400000   3: patch_drum
      0x11600000   4: patch_drum
      0x12000000   5: patch_drum
      0x12200000   6: patch_drum
      0x12400000   7: patch_drum
      0x12600000   8: patch_drum
      0x13000000   9: patch_drum
      0x13200000  10: patch_drum
      0x13400000  11: patch_drum
      0x13600000  12: patch_drum
      0x14000000  13: patch_drum
      0x14200000  14: patch_drum
      0x14400000  15: patch_drum
      0x14600000  16: patch_drum
    0x1e000000 rhythm_pattern:      arpeggio
    0x1e110000 arpeggio:            arpeggio
    0x1e130000 rhythm_group:        rhythm_group
    0x1e150000 vocal_effect:        vocal_effect
    0x1f000000 patch_part: # patch mode part 1
      0x000000 x1: patch_drum
      0x200000 x2: patch_drum
  user:
    0x20000000 performance:  performance_patterns
    0x21000000 pattern:      performance_patterns
    0x30000000 patch:        performance_patches
    0x40000000 drum_kit:     drum_kits
    0x60000000 vocal_effect: vocal_effects
