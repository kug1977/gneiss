
with Ada.Unchecked_Conversion;
with Interfaces;
with Componolit.Interfaces.Muchannel_Writer;
with Componolit.Interfaces.Muchannel_Reader;

package Componolit.Interfaces.Muen_Block with
   SPARK_Mode
is
   Event_Block_Size : constant := 4096;

   type Count is range 0 .. 2 ** 63 - 1 with
      Size => 64;

   type Sector is range 0 .. 2 ** 63 - 1 with
      Size => 64;

   type Session_Name is new String (1 .. 59);
   Null_Name : constant Session_Name := (others => Character'First);

   --  The sector field is used to determine the command type if the event is a command
   Sync : constant Sector := 0;
   Size : constant Sector := 1;

   type Event_Type is (Read,
                       Write,
                       Command,
                       Last) with
      Size => 32;
   for Event_Type use (Read    => 0,
                       Write   => 1,
                       Command => 2,
                       Last    => 3);

   type Padding_Type is array (Natural range <>) of Standard.Interfaces.Unsigned_8;

   type Raw_Data_Type is array (1 .. Event_Block_Size) of Standard.Interfaces.Unsigned_8 with
      Size => 32768;

   type Size_Command_Data_Type is record
      Value : Count;
      Pad   : Padding_Type (1 .. 4088);
   end record;

   for Size_Command_Data_Type use record
      Value at 0 range 0 .. 63;
      Pad   at 8 range 0 .. 32703;
   end record;

   type Event is record
      Kind  : Event_Type;
      Error : Integer;
      Id    : Sector;
      Priv  : Standard.Interfaces.Unsigned_64;
      Data  : Raw_Data_Type;
   end record;

   for Event use record
      Kind  at  0 range 0 .. 31;
      Error at  4 range 0 .. 31;
      Id    at  8 range 0 .. 63;
      Priv  at 16 range 0 .. 63;
      Data  at 24 range 0 .. 32767;
   end record;

   Null_Event : constant Event := (Kind  => Read,
                                   Error => 0,
                                   Id    => Sync,
                                   Priv  => 0,
                                   Data  => (others => 0));

   Element_Count : constant Positive := 16#0010_0000# / (Event'Size / 8);

   package Request_Channel is new Componolit.Interfaces.Muchannel_Writer
      (Element_Type => Event,
       Elements     => Element_Count,
       Null_Element => Null_Event,
       Protocol     => 16#9570_208d_ca77_db19#);

   package Response_Channel is new Componolit.Interfaces.Muchannel_Reader
      (Element_Type => Event,
       Elements     => Element_Count,
       Null_Element => Null_Event,
       Protocol     => 16#9851_be32_82fe_f0dc#);

   function Get_Size_Command_Data is new Ada.Unchecked_Conversion (Raw_Data_Type, Size_Command_Data_Type);

end Componolit.Interfaces.Muen_Block;