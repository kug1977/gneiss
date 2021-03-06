
with Gneiss.Memory;
with Gneiss.Memory.Dispatcher;
with Gneiss.Memory.Server;

package body Component with
   SPARK_Mode,
   Refined_State => (Component_State => Capability,
                     Platform_State  => (Dispatcher,
                                         Servers,
                                         Server_Data))
is

   package Memory is new Gneiss.Memory (Character, Positive, String);

   type Server_Slot is record
      Ident : String (1 .. 513) := (others => ASCII.NUL);
      Ready : Boolean := False;
   end record;

   subtype Server_Index is Gneiss.Session_Index range 1 .. 2;
   type Server_Reg is array (Server_Index'Range) of Memory.Server_Session;
   type Server_Meta is array (Server_Index'Range) of Server_Slot;

   Dispatcher  : Memory.Dispatcher_Session;
   Capability  : Gneiss.Capability;
   Servers     : Server_Reg;
   Server_Data : Server_Meta;

   function Contract (Ctx : Server_Meta) return Boolean is (True);

   procedure Modify (Session : in out Memory.Server_Session;
                     Data    : in out String;
                     Context : in out Server_Meta) with
      Pre    => Memory.Initialized (Session)
                and then Ready (Session, Context)
                and then Contract (Context),
      Post   => Memory.Initialized (Session)
                and then Ready (Session, Context)
                and then Contract (Context),
      Global => null;

   procedure Initialize (Session : in out Memory.Server_Session;
                         Context : in out Server_Meta) with
      Pre    => Memory.Initialized (Session),
      Post   => Memory.Initialized (Session),
      Global => null;

   procedure Finalize (Session : in out Memory.Server_Session;
                       Context : in out Server_Meta) with
      Pre    => Memory.Initialized (Session),
      Post   => Memory.Initialized (Session),
      Global => null;

   function Ready (Session : Memory.Server_Session;
                   Context : Server_Meta) return Boolean with
      Global => null;

   procedure Dispatch (Session  : in out Memory.Dispatcher_Session;
                       Disp_Cap :        Memory.Dispatcher_Capability;
                       Name     :        String;
                       Label    :        String) with
      Pre    => Memory.Initialized (Session)
                and then Memory.Registered (Session),
      Post   => Memory.Initialized (Session)
                and then Memory.Registered (Session),
      Global => (In_Out => (Servers, Server_Data,
                            Gneiss_Internal.Platform_State));

   package Memory_Server is new Memory.Server (Server_Meta, Modify, Initialize, Finalize, Ready);
   package Memory_Dispatcher is new Memory.Dispatcher (Memory_Server, Dispatch);

   procedure Modify is new Memory_Server.Modify (Contract);

   procedure Construct (Cap : Gneiss.Capability)
   is
   begin
      Capability := Cap;
      Memory_Dispatcher.Initialize (Dispatcher, Cap);
      if Memory.Initialized (Dispatcher) then
         Memory_Dispatcher.Register (Dispatcher);
      else
         Main.Vacate (Capability, Main.Failure);
      end if;
   end Construct;

   procedure Destruct
   is
   begin
      null;
   end Destruct;

   procedure Modify (Session : in out Memory.Server_Session;
                     Data    : in out String;
                     Context : in out Server_Meta)
   is
      pragma Unreferenced (Session);
      pragma Unreferenced (Context);
   begin
      if Data'Length > 11 then
         Data (Data'First .. Data'First + 11) := "Hello World!";
      end if;
   end Modify;

   procedure Initialize (Session : in out Memory.Server_Session;
                         Context : in out Server_Meta)
   is
   begin
      if Memory.Index (Session).Value in Context'Range then
         Context (Memory.Index (Session).Value).Ready := True;
      end if;
   end Initialize;

   procedure Finalize (Session : in out Memory.Server_Session;
                       Context : in out Server_Meta)
   is
   begin
      if Memory.Index (Session).Value in Context'Range then
         Context (Memory.Index (Session).Value).Ready := False;
      end if;
   end Finalize;

   procedure Dispatch (Session  : in out Memory.Dispatcher_Session;
                       Disp_Cap :        Memory.Dispatcher_Capability;
                       Name     :        String;
                       Label    :        String)
   is
   begin
      if Memory_Dispatcher.Valid_Session_Request (Session, Disp_Cap) then
         for I in Servers'Range loop
            if
               not Ready (Servers (I), Server_Data)
               and then not Memory.Initialized (Servers (I))
               and then Name'Length < Server_Data (I).Ident'Last
               and then Label'Length < Server_Data (I).Ident'Last
               and then Name'Length + Label'Length + 1 <= Server_Data (I).Ident'Last
               and then Name'First < Integer'Last - Server_Data (I).Ident'Last
            then
               Memory_Dispatcher.Session_Initialize (Session, Disp_Cap, Servers (I), Server_Data, I);
               if Ready (Servers (I), Server_Data) and then Memory.Initialized (Servers (I)) then
                  Server_Data (I).Ident (1 .. Name'Length + Label'Length + 1) := Name & ":" & Label;
                  Memory_Dispatcher.Session_Accept (Session, Disp_Cap, Servers (I), Server_Data);
                  exit;
               end if;
            end if;
         end loop;
      end if;
      for S of Servers loop
         Memory_Dispatcher.Session_Cleanup (Session, Disp_Cap, S, Server_Data);
      end loop;
      for S of Servers loop
         if Memory.Initialized (S) and then Ready (S, Server_Data) then
            Modify (S, Server_Data);
         end if;
      end loop;
   end Dispatch;

   function Ready (Session : Memory.Server_Session;
                   Context : Server_Meta) return Boolean is
      (if
          Memory.Index (Session).Valid
          and then Memory.Index (Session).Value in Context'Range
       then Context (Memory.Index (Session).Value).Ready
       else False);

end Component;
