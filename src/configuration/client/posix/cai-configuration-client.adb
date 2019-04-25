
with System;
with C;

package body Cai.Configuration.Client with
   SPARK_Mode => Off
is

   use type System.Address;
   use type C.Uint64_T;

   function Create return Client_Session
   is
   begin
      return Client_Session'(Fd   => -1,
                             Map  => System.Null_Address,
                             Size => 10);
   end Create;

   function Initialized (C : Client_Session) return Boolean
   is
   begin
      return C.Fd >= 0
             and C.Map /= System.Null_Address
             and C.Size > 0;
   end Initialized;

   procedure Initialize (C   : in out Client_Session;
                         Cap :        Cai.Types.Capability)
   is
      procedure C_Initialize (S : in out Client_Session;
                              C : Cai.Types.Capability) with
         Import,
         Convention => C,
         External_Name => "configuration_client_initialize";
   begin
      C_Initialize (C, Cap);
   end Initialize;

   procedure Load (C : in out Client_Session)
   is
      Last : constant Index := Index (C.Size / (Element'Size / 8));
      Data : Buffer (1 .. Last) with
        Address => C.Map;
   begin
      Parse (Data);
   end Load;

   procedure Finalize (C : in out Client_Session)
   is
      procedure C_Finalize (C : in out Client_Session) with
         Import,
         Convention => C,
         External_Name => "configuration_client_finalize";
   begin
      C_Finalize (C);
   end Finalize;

end Cai.Configuration.Client;