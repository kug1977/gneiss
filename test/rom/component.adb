
with Gneiss.Rom;
with Gneiss.Rom.Client;
with Gneiss.Log;
with Gneiss.Log.Client;

package body Component with
   SPARK_Mode,
   Refined_State => (Component_State => C,
                     Platform_State  => (Log, Config))
is

   package Gneiss_Log is new Gneiss.Log;
   package Log_Client is new Gneiss_Log.Client;
   package Rom is new Gneiss.Rom (Character, Positive, String);

   C      : Gneiss.Capability;
   Log    : Gneiss_Log.Client_Session;
   Config : Rom.Client_Session;

   procedure Read (Session : in out Rom.Client_Session;
                   Data    :        String;
                   Ctx     : in out Gneiss_Log.Client_Session) with
      Pre    => Rom.Initialized (Session)
                and then Gneiss_Log.Initialized (Ctx),
      Post   => Rom.Initialized (Session)
                and then Gneiss_Log.Initialized (Ctx),
      Global => (In_Out => Gneiss_Internal.Platform_State);

   package Rom_Client is new Rom.Client (Gneiss_Log.Client_Session, Read);
   procedure Update is new Rom_Client.Update (Gneiss_Log.Initialized);

   procedure Construct (Capability : Gneiss.Capability)
   is
   begin
      C := Capability;
      Log_Client.Initialize (Log, C, "rom");
      Rom_Client.Initialize (Config, C, "config");
      if Gneiss_Log.Initialized (Log) and then Rom.Initialized (Config) then
         Update (Config, Log);
         Main.Vacate (C, Main.Success);
      else
         Main.Vacate (C, Main.Failure);
      end if;
   end Construct;

   procedure Read (Session : in out Rom.Client_Session;
                   Data    :        String;
                   Ctx     : in out Gneiss_Log.Client_Session)
   is
      pragma Unreferenced (Session);
      Prefix : constant String := "Rom content: ";
      Last   : Integer;
   begin
      if Data'Length < Positive'Last - Prefix'Length then
         Last := Data'Last;
      else
         Last := Data'Last - Prefix'Length;
      end if;
      Log_Client.Info (Ctx, Prefix & Data (Data'First .. Last));
   end Read;

   procedure Destruct
   is
   begin
      Log_Client.Finalize (Log);
      Rom_Client.Finalize (Config);
   end Destruct;

end Component;
