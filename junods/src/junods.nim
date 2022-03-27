import strutils

type
  Kind = enum
    TNone,
    TBool,
    TNibble,
    TEnum,
    TByte,
    TNibblePair,
    TNibbleQuad,
    TName,
  JAddr = int32

type
  Mem = object # tree structure for describing areas of device memory
    offset: JAddr
    kind:   Kind
    name:   string
    area*:  seq[Mem]
  MemArea = seq[Mem]

proc CM(offset: JAddr, name: string, kind: Kind = TNone): Mem =
  Mem(offset: offset, name: name, kind: kind)

proc CMA(offset: JAddr, name: string, area: varargs[Mem]): Mem =
  Mem(offset: offset, name: name, area: @area)

proc CMAO(name: string, area: varargs[Mem]): Mem =
  CMA(-1, name, area)

let scale_map = @[
  CM(0x00, "c" , TByte),
  CM(0x01, "c#", TByte),
  CM(0x02, "d" , TByte),
  CM(0x03, "d#", TByte),
  CM(0x04, "e" , TByte),
  CM(0x05, "f" , TByte),
  CM(0x06, "f#", TByte),
  CM(0x07, "g" , TByte),
  CM(0x08, "g#", TByte),
  CM(0x09, "a" , TByte),
  CM(0x0a, "a#", TByte),
  CM(0x0b, "b" , TByte),
]

proc voice_reserve(): seq[Mem] =
  for i in 0..15:
    result.add(CM(JAddr(i), $(i+1), TByte))

let control = @[
  CMA(0, "1",
    CM(0, "source", TEnum),
    CM(1, "sens", TByte),
  ),
  CMA(2, "2",
    CM(0, "source", TEnum),
    CM(1, "sens", TByte),
  ),
  CMA(4, "3",
    CM(0, "source", TEnum),
    CM(1, "sens", TByte),
  ),
  CMA(6, "4",
    CM(0, "source", TEnum),
    CM(1, "sens", TByte),
  ),
  CMA(8, "assign",
    CM(0, "1", TEnum),
    CM(1, "2", TEnum),
    CM(2, "3", TEnum),
    CM(3, "4", TEnum),
  ),
]

proc parameter(n: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    result.add( CM(JAddr(4*i), $(i+1), TNibbleQuad) )

let mfx = @[
  CM( 0x00, "type", TEnum),
  CM( 0x01, "dry_send", TEnum),
  CM( 0x02, "chorus_send", TEnum),
  CM( 0x03, "reverb_send", TEnum),
  CM( 0x04, "output_asssign", TEnum),
  CMA(0x05, "control", control),
  CMA(0x11, "parameter",
    parameter(28) & @[
      CM(0xf0, "29", TNibbleQuad),
      CM(0xf4, "30", TNibbleQuad),
      CM(0xf8, "31", TNibbleQuad),
      CM(0xfc, "32", TNibbleQuad),
    ],
  ),
]

let midi_n = @[
  CMAO("rx",
    CM(0x00, "pc"),
    CM(0x01, "bank"),
    CM(0x02, "bend"),
    CM(0x03, "key_pressure"),
    CM(0x04, "channel_pressure"),
    CM(0x05, "modulation"),
    CM(0x06, "volume"),
    CM(0x07, "pan"),
    CM(0x08, "expression"),
    CM(0x09, "hold_1"),
  ),
  CM(0x0a, "phase_lock"),
  CM(0x0b, "velocity_curve_type"),
]

proc midi(): seq[Mem] =
  for i in 0..15:
    result.add( CMA(JAddr(0x100*i), $(i+1), midi_n) )

let juno_map = CMAO("junods",
  CMA(0x01000000, "setup",
    CM(     0x00, "sound_mode", TEnum),
    CMAO(         "performance",
      CM(   0x01, "bank_msb", TByte),
      CM(   0x02, "bank_lsb", TByte),
      CM(   0x03, "pc", TByte),
    ),
    CMAO(          "kbd_patch",
      CM(   0x04, "bank_msb", TByte),
      CM(   0x06, "bank_lsb", TByte),
      CM(   0x07, "pc", TByte),
    ),
    CMAO(         "rhy_patch",
      CM(   0x07, "bank_msb", TByte),
      CM(   0x08, "bank_lsb", TByte),
      CM(   0x09, "pc", TByte),
      CM(   0x0a, "mfx1_switch", TBool),
      CM(   0x0b, "mfx2_switch", TBool),
      CM(   0x0c, "mfx3_switch", TBool),
      CM(   0x0d, "chorus_switch", TBool),
      CM(   0x0e, "reverb_switch", TBool),
      CM(   0x0f, "reserved_1"),
      CM(   0x12, "transpose", TByte),
      CM(   0x13, "octave", TByte),
      CM(   0x14, "reserved_4"),
      CM(   0x15, "knob_select", TByte),
      CM(   0x16, "reserved_5"),
      CMAO(       "arpeggio",
        CM( 0x17, "grid", TEnum),
        CM( 0x18, "duration", TEnum),
        CM( 0x19, "switch", TBool),
        CM( 0x1a, "reserved_6"),
        CM( 0x1b, "style", TByte),
        CM( 0x1c, "motif", TEnum),
        CM( 0x1d, "octave", TByte),
        CM( 0x1e, "hold", TBool),
        CM( 0x1f, "accent", TByte),
        CM( 0x20, "velocity", TByte),
      ),
      CMAO(       "rhythm",
        CM( 0x21, "switch", TBool),
        CM( 0x22, "reserved_7"),
        CM( 0x23, "style", TNibblePair),
        CM( 0x25, "reserved_8"),
        CM( 0x26, "group", TByte),
        CM( 0x27, "accent", TByte),
        CM( 0x28, "velocity", TByte),
        CM( 0x29, "reserved_9"),
      ),
      CM(   0x33, "arpeggio_step", TByte),
    ),
  ),
  CMA(0x02000000, "system",
    CMA(0x000000, "common",
      CMA(0x0000, "master",
        CM( 0x00, "tune", TNibbleQuad),
        CM( 0x04, "key_shift", TByte),
        CM( 0x05, "level", TByte),
      ),
      CM(   0x06, "scale_switch", TBool),
      CM(   0x07, "patch_remain", TBool),
      CM(   0x08, "mix_parallel", TBool),
      CM(   0x09, "channel", TBool),
      CM(   0x0a, "kbd_patch_channel", TBool),
      CM(   0x0b, "reserved_1", TBool),
      CMA(  0x0c, "scale", scale_map),
      CMAO(       "control_source",
        CM( 0x18, "1", TEnum),
        CM( 0x19, "2", TEnum),
        CM( 0x1a, "3", TEnum),
        CM( 0x1b, "4", TEnum),
      ),
      CMAO(       "rx",
        CM( 0x1c, "pc", TByte),
        CM( 0x1d, "bank", TByte),
      ),
    ),
    CMA(0x004000, "controller",
      CMAO(       "tx",
        CM( 0x00, "pc", TByte),
        CM( 0x01, "bank", TByte),
      ),
      CM(   0x02, "velocity", TByte),
      CM(   0x03, "velocity_curve", TEnum),
      CM(   0x04, "reserved_1"),
      CM(   0x05, "hold_polarity", TBool),
      CM(   0x06, "continuous_hold", TBool),
      CMAO(       "control_pedal",
        CM( 0x07, "assign", TEnum),
        CM( 0x08, "polarity", TEnum),
      ),
      CM(   0x09, "reserved_2"),
      CMAO(       "knob_assign",
        CM( 0x10, "1", TByte),
        CM( 0x11, "2", TByte),
        CM( 0x12, "3", TByte),
        CM( 0x13, "4", TByte),
      ),
      CM(   0x14, "reserved_2"),
      CM(   0x4d, "reserved_3"),
    ),
  ),
  CMA(0x10000000, "temporary",
    CMA(0x000000, "performance_pattern",
      CMA(0x0000, "common",
        CM( 0x00, "name", TName),
        CM( 0x0c, "solo", TBool),
        CM( 0x0d, "mfx1_channel", TByte),
        CM( 0x0e, "reserved_1"),
        CM( 0x0f, "reserved_2"),
        CMA(0x10, "voice_reserve", voice_reserve()),
        CM( 0x20, "reserved_3"),
        CM( 0x30, "mfx1_source", TEnum),
        CM( 0x31, "mfx2_source", TEnum),
        CM( 0x32, "mfx3_source", TEnum),
        CM( 0x33, "chorus_source", TEnum),
        CM( 0x34, "reverb_source", TEnum),
        CM( 0x35, "mfx2_channel", TEnum),
        CM( 0x36, "mfx3_channel", TEnum),
        CM( 0x37, "mfx_structure", TEnum),
      ),
      CMA(0x0200, "mfx1", mfx),
      CMA(0x0400, "chorus",
        CM( 0x00, "type", TEnum),
        CM( 0x01, "level", TByte),
        CM( 0x02, "output_assign", TEnum),
        CM( 0x03, "output_select", TEnum),
        CMA(0x04, "parameter", parameter(20)),
      ),
      CMA(0x0600, "reverb",
        CM( 0x00, "type", TEnum),
        CM( 0x01, "level", TByte),
        CM( 0x02, "output_assign", TEnum),
        CMA(0x03, "parameter", parameter(20)),
      ),
      CMA(0x0800, "mfx2", mfx),
      CMA(0x0a00, "mfx3", mfx),
      CMA(0x1000, "midi", midi()),
      CMA(0x2000, "part",
      ),
    ),
  ),
)

proc traverse(mem: Mem, offset: JAddr, level: int) =
  var a = offset
  if mem.offset >= 0:
    a += mem.offset
    stdout.write "0x", a.toHex(8).toLower(), " "
  else:
    stdout.write "           "

  stdout.write indent(mem.name, level * 4)
  stdout.write "\n"
  for area in mem.area:
    traverse(area, a, level + 1)

when isMainModule:
  traverse(juno_map, 0, 0)
