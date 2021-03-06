with Gneiss_Internal.Syscall;
with Gneiss_Internal.Message_Syscall;
with Gneiss_Internal.Client;
with Gneiss_Protocol.Session;

package body Gneiss.Log.Client with
   SPARK_Mode
is

   procedure Prefix_Message (Session : in out Client_Session;
                             Prefix  :        String;
                             Msg     :        String;
                             Newline :        Boolean) with
      Pre  => Initialized (Session),
      Post => Initialized (Session);

   procedure Flush_Buffer (Session : in out Client_Session) with
      Pre    => Initialized (Session),
      Post   => Initialized (Session)
                and then Session.Cursor = 0,
      Global => (In_Out => Gneiss_Internal.Platform_State);

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Session : in out Client_Session;
                         Cap     :        Capability;
                         Label   :        String)
   is
      use type Gneiss_Internal.File_Descriptor;
      Fds : Gneiss_Internal.Fd_Array (1 .. 1) := (others => -1);
   begin
      if Initialized (Session) or else Label'Length > 255 then
         return;
      end if;
      Gneiss_Internal.Client.Initialize (Cap.Broker_Fd, Gneiss_Protocol.Session.Log, Fds, Label);
      if Fds (Fds'First) < 0 then
         return;
      end if;
      Session.Label.Last := Session.Label.Value'First + Label'Length - 1;
      Session.Label.Value
         (Session.Label.Value'First
          .. Session.Label.Value'First + Label'Length - 1) := Label;
      Session.Fd := Fds (Fds'First);
   end Initialize;

   --------------
   -- Finalize --
   --------------

   procedure Finalize (Session : in out Client_Session)
   is
   begin
      Gneiss_Internal.Syscall.Close (Session.Fd);
      Session.Label.Last := 0;
   end Finalize;

   -----------
   -- Print --
   -----------

   procedure Print (Session : in out Client_Session;
                    Msg     :        String)
   is
   begin
      pragma Assert (Initialized (Session));
      if Session.Cursor >= Session.Buffer'Last then
         Flush_Buffer (Session);
      end if;
      for C of Msg loop
         pragma Loop_Invariant (Initialized (Session));
         pragma Loop_Invariant (Session.Cursor < Session.Buffer'Last);
         Session.Cursor := Session.Cursor + 1;
         Session.Buffer (Session.Cursor) := C;
         if
            (C = ASCII.LF and then Session.Cursor < Session.Buffer'Last)
            or else Session.Cursor >= Session.Buffer'Last
         then
            Flush_Buffer (Session);
         end if;
      end loop;
   end Print;

   ----------
   -- Info --
   ----------

   procedure Info (Session : in out Client_Session;
                   Msg     :        String;
                   Newline :        Boolean := True)
   is
   begin
      Prefix_Message (Session, "Info: ", Msg, Newline);
   end Info;

   -------------
   -- Warning --
   -------------

   procedure Warning (Session : in out Client_Session;
                      Msg     :        String;
                      Newline :        Boolean := True)
   is
   begin
      Prefix_Message (Session, "Warning: ", Msg, Newline);
   end Warning;

   -----------
   -- Error --
   -----------

   procedure Error (Session : in out Client_Session;
                    Msg     :        String;
                    Newline :        Boolean := True)
   is
   begin
      Prefix_Message (Session, "Error: ", Msg, Newline);
   end Error;

   -----------
   -- Flush --
   -----------

   procedure Flush_Buffer (Session : in out Client_Session) with
      SPARK_Mode => Off
   is
   begin
      if Session.Cursor < Session.Buffer'Last then
         Session.Buffer (Session.Cursor + 1) := ASCII.NUL;
      end if;
      Gneiss_Internal.Message_Syscall.Write (Session.Fd,
                                             Session.Buffer'Address,
                                             Session.Buffer'Length);
      Session.Cursor := 0;
   end Flush_Buffer;

   procedure Flush (Session : in out Client_Session)
   is
   begin
      Flush_Buffer (Session);
   end Flush;

   procedure Prefix_Message (Session : in out Client_Session;
                             Prefix  :        String;
                             Msg     :        String;
                             Newline :        Boolean)
   is
   begin
      Print (Session, Prefix);
      Print (Session, Msg);
      if Newline then
         Print (Session, String'(1 => ASCII.LF));
      end if;
   end Prefix_Message;

end Gneiss.Log.Client;
