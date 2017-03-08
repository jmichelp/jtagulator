{{
┌─────────────────────────────────────────────────┐
│ ARM Serial Wire Debug                           │
│ Interface Object                                │
│                                                 │
│ Author: Jean-Michel Picod                       │
│                                                 │
│ Distributed under a Creative Commons            │
│ Attribution 3.0 United States license           │
│ http://creativecommons.org/licenses/by/3.0/us/  │
└─────────────────────────────────────────────────┘

}}

CON
  SWD_ACK = %001
  SWD_WAIT = %010
  SWD_FAULT = %100
  SWD_DISCONNECT = %111

  SWD_DP = 0
  SWD_AP = 1

  WRITE = 0
  READ = 1

  PARITY_MASK = %01111000

VAR
  long SWCLK, SWDIO       ' ARM SWD pins (must stay in this order)

  byte master

  long reg_value
  byte last_ack
  byte parity
OBJ


PUB Config(clk_pin, data_pin)
{
  Set SWD pins
  Parameters : SWCLK, SWDIO channels provided by top object
}
  longmove(@SWCLK, @clk_pin, 2)
  reg_value := 0
  last_ack := 0
  parity := 0
  master := 1
  dira[SWCLK] := 1
  outa[SWCLK] := 0  ' put idle CLK to LOW
  DataOut
  StrobeData

PUB Idle(cycles)
  outa[SWDIO] := 0
  repeat cycles
    CLKPulse

PUB Idcode
  return ReadDebugPort(0)

PUB SendPacket(APnDP, RnW, address) | data, ack, i
{
  TODO

  Parameters : APnDP = Operationg is on DP if 0 otherwise on AP
               RnW = Write operation if 0 otherwise read
               address = Address to read
  Returns    : ACK value (3 bits)
}

  data := %10000001 ' Packet with start and park bits set
  data |= ((APnDP & 1) << 6)
  data |= ((RnW & 1) << 5)
  data |= (address & $c)
  ' Set parity
  data |= (ComputeParity(((data & PARITY_MASK) >> 3), 4) << 2)
  data ><= 8
  WriteDataBits(data, 8)
  TRN
  return ReadDataBits(3)

PUB GetValue
  return reg_value

PUB GetAck
  return last_ack

PUB GetParity
  return parity

PUB SWDRead(APnDP, address)
  reg_value := 0
  parity := 0
  last_ack := SendPacket(APnDP, READ, address)
  reg_value := ReadDataBits(32)
  parity := ReadDataBits(1)
  TRN
  return parity == ComputeParity(reg_value, 32)

PUB SWDWrite(APnDP, address, value)
  parity := ComputeParity(value, 32)
  last_ack := SendPacket(APnDP, WRITE, address)
  TRN
  if (last_ack == SWD_ACK)
    WriteDataBits(value, 32)
    WriteDataBits(parity, 1)
  return last_ack

PUB ReadDebugPort(address)
  return SWDRead(SWD_DP, address)

PUB ReadAccessPort(address)
  return SWDRead(SWD_AP, address)

PUB WriteDebugPort(address, value)
  return SWDWrite(SWD_DP, address, value)

PUB WriteAccessPort(address, value)
  return SWDWrite(SWD_AP, address, value)

PUB Reset
{
  Sets IO to high for 50 cycles followed by a 0
}
  if master == 0
    TRN
  WriteDataBits($ffffffff, 32)
  WriteDataBits($ffffffff, 18)
  WriteDataBits(0, 1)

PUB Jtag2SWD | i, len
{
  JTAG-to-SWD sequence is at least 50 cycles with IO set to HIGH,
  followed by a 16 bits magic value and a reset sequence
}
  if master == 0
    TRN
  WriteDataBits($ffffffff, 32)
  WriteDataBits($ffffffff, 21)
  WriteDataBits($e79e, 16)  ' LSB first
  Reset
  Idle(1)

PUB SWD2Jtag
  if master == 0
    TRN
  WriteDataBits($ffffffff, 32)
  WriteDataBits($ffffffff, 18)
  WriteDataBits($e73c, 16)  ' LSB first
  WriteDataBits($ffffffff, 5)

PRI DataIn
  dira[SWDIO] := 0

PRI DataOut
  outa[SWDIO] := 1
  dira[SWDIO] := 1

PRI StrobeData
  outa[SWDIO] := 0
  outa[SWDIO] := 1

PRI ComputeParity(value, nb_bits)
  parity := 0
  repeat nb_bits
    parity ^= (value & 1)
    value >>= 1
  return parity

PRI ReadDataBits(nb_bits) | value
  value := 0
  repeat nb_bits
    value <<= 1
    value |= CLKPulse
  return value >< nb_bits

PRI WriteDataBits(value, nb_bits)
  repeat nb_bits
    outa[SWDIO] := (value & 1)
    CLKPulse
    value >>= 1

PRI TRN
  !outa[SWCLK]
  if master == 0
    DataOut
    CLKPulse
  else
    DataIn
  master ^= 1

PRI CLKPulse
  !outa[SWCLK]
  if dira[SWDIO] == 0
    result := ina[SWDIO]
  else
    result := 0
  !outa[SWCLK]

DAT

