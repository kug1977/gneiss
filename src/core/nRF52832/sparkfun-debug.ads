with System;

package Sparkfun.Debug with
SPARK_Mode
is

   procedure Initialize;

   generic
      type T is (<>);
   procedure Debug (Value : T);
   procedure Debug_Address (Adr : System.Address);

private

   type Array_Index is range 1 .. 8;

   type Pin_Array is array (Array_Index'Range) of GPIO.Pin;
   --  Sparkfun
   --  Pins : constant Pin_Array := (24, 23, 22, 20, 12, 11, 13, 14);
   Pins : constant Pin_Array := (28, 29, 30, 31, 25, 24, 23, 22);

   type Value_Array is array (Array_Index'Range) of GPIO.Value;

end Sparkfun.Debug;
