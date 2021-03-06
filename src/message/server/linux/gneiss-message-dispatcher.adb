
with System;
with Gneiss_Internal.Epoll;
with Gneiss_Internal.Client;
with Gneiss_Internal.Syscall;
with Gneiss_Internal.Message_Syscall;
with Gneiss_Protocol.Session;

package body Gneiss.Message.Dispatcher with
   SPARK_Mode
is

   function Server_Event_Address (Session : Server_Session) return System.Address;
   function Dispatch_Event_Address (Session : Dispatcher_Session) return System.Address;

   procedure Session_Event (Session : in out Server_Session;
                            Fd      :        Gneiss_Internal.File_Descriptor);
   procedure Dispatch_Event (Session : in out Dispatcher_Session;
                             Fd      :        Gneiss_Internal.File_Descriptor);
   procedure Dispatch_Error (Session : in out Dispatcher_Session;
                             Fd      :        Gneiss_Internal.File_Descriptor);

   function Event_Cap is new Gneiss_Internal.Create_Event_Cap (Server_Session,
                                                               Dispatcher_Session,
                                                               Session_Event,
                                                               Dispatch_Event);
   function Dispatch_Cap is new Gneiss_Internal.Create_Event_Cap (Dispatcher_Session,
                                                                  Dispatcher_Session,
                                                                  Dispatch_Event,
                                                                  Dispatch_Error);

   function Available (Session : Server_Session) return Boolean is
      (Gneiss_Internal.Message_Syscall.Peek (Session.Fd) >= Message_Buffer'Size * 8) with
         Pre => Initialized (Session);

   procedure Read (Session : in out Server_Session;
                   Data    :    out Message_Buffer) with
      Pre  => Initialized (Session),
      Post => Initialized (Session);

   procedure Read (Session : in out Server_Session;
                   Data    :    out Message_Buffer) with
      SPARK_Mode => Off
   is
   begin
      Gneiss_Internal.Message_Syscall.Read (Session.Fd, Data'Address, Data'Size * 8);
   end Read;

   procedure Session_Event (Session : in out Server_Session;
                            Fd      :        Gneiss_Internal.File_Descriptor)
   is
      pragma Unreferenced (Fd);
      Buffer : Message_Buffer;
   begin
      if not Initialized (Session) then
         return;
      end if;
      if Available (Session) then
         Read (Session, Buffer);
         Server_Instance.Receive (Session, Buffer);
      end if;
   end Session_Event;

   function Server_Event_Address (Session : Server_Session) return System.Address with
      SPARK_Mode => Off
   is
   begin
      return Session.E_Cap'Address;
   end Server_Event_Address;

   function Dispatch_Event_Address (Session : Dispatcher_Session) return System.Address with
      SPARK_Mode => Off
   is
   begin
      return Session.E_Cap'Address;
   end Dispatch_Event_Address;

   procedure Dispatch_Event (Session : in out Dispatcher_Session;
                             Fd      :        Gneiss_Internal.File_Descriptor)
   is
      use type Gneiss_Internal.File_Descriptor;
      Fds   : Gneiss_Internal.Fd_Array (1 .. 2);
      Name  : Gneiss_Internal.Session_Label;
      Label : Gneiss_Internal.Session_Label;
   begin
      if not Initialized (Session) or else not Gneiss_Internal.Valid (Session.Dispatch_Fd) then
         return;
      end if;
      if Fd = Session.Dispatch_Fd then
         Session.Accepted := False;
         Gneiss_Internal.Client.Dispatch (Session.Dispatch_Fd, Gneiss_Protocol.Session.Message,
                                          Name, Label, Fds);
         Dispatch (Session,
                   Dispatcher_Capability'(Client_Fd => Fds (1),
                                          Server_Fd => Fds (2),
                                          Clean_Fd  => -1,
                                          Name      => Name,
                                          Label     => Label),
                   Name.Value (Name.Value'First .. Name.Last),
                   Label.Value (Label.Value'First .. Label.Last));
         if not Session.Accepted then
            Gneiss_Internal.Client.Reject (Session.Dispatch_Fd,
                                           Gneiss_Protocol.Session.Message,
                                           Name.Value (Name.Value'First .. Name.Last),
                                           Label.Value (Label.Value'First .. Label.Last));
         end if;
      else
         --  If Fd /= Dispatch_Fd a server session has been closed by a client. So
         --  Dispatch will be called with an invalid capability that carries the
         --  file descriptor as Clean_Fd which is then used to clean up the disconnected
         --  session in Session_Cleanup.
         Dispatch (Session,
                   Dispatcher_Capability'(Client_Fd => -1,
                                          Server_Fd => -1,
                                          Clean_Fd  => Fd,
                                          Name      => Name,
                                          Label     => Label),
                   "", "");
      end if;
   end Dispatch_Event;

   procedure Dispatch_Error (Session : in out Dispatcher_Session;
                             Fd      :        Gneiss_Internal.File_Descriptor)
   is
      use type Gneiss_Internal.File_Descriptor;
      Ignore_Success : Boolean;
   begin
      if not Initialized (Session) then
         return;
      end if;
      if Fd = Session.Dispatch_Fd and then Gneiss_Internal.Valid (Session.Dispatch_Fd) then
         Gneiss_Internal.Epoll.Remove (Session.Efd, Session.Dispatch_Fd, Ignore_Success);
      end if;
   end Dispatch_Error;

   procedure Initialize (Session : in out Dispatcher_Session;
                         Cap     :        Capability;
                         Idx     :        Session_Index := 1)
   is
   begin
      if Initialized (Session) then
         return;
      end if;
      Session.Efd       := Cap.Efd;
      Session.Index     := Gneiss.Session_Index_Option'(Valid => True, Value => Idx);
      Session.Broker_Fd := Cap.Broker_Fd;
      Gneiss_Internal.Syscall.Modify_Platform;
   end Initialize;

   procedure Register (Session : in out Dispatcher_Session)
   is
      Ignore_Success : Boolean;
   begin
      if Gneiss_Internal.Valid (Session.Dispatch_Fd) then
         return;
      end if;
      Gneiss_Internal.Client.Register (Session.Broker_Fd, Gneiss_Protocol.Session.Message, Session.Dispatch_Fd);
      if Gneiss_Internal.Valid (Session.Dispatch_Fd) then
         Session.E_Cap      := Dispatch_Cap (Session, Session, Session.Dispatch_Fd);
         Gneiss_Internal.Epoll.Add (Session.Efd, Session.Dispatch_Fd,
                                    Dispatch_Event_Address (Session), Ignore_Success);
      end if;
   end Register;

   function Valid_Session_Request (Session : Dispatcher_Session;
                                   Cap     : Dispatcher_Capability) return Boolean is
      (Gneiss_Internal.Valid (Cap.Client_Fd) and then Gneiss_Internal.Valid (Cap.Server_Fd));

   procedure Session_Initialize (Session  : in out Dispatcher_Session;
                                 Cap      :        Dispatcher_Capability;
                                 Server_S : in out Server_Session;
                                 Ctx      : in out Server_Instance.Context;
                                 Idx      :        Session_Index := 1)
   is
   begin
      if Message_Buffer'Size /= 128 * 8 then
         return;
      end if;
      Server_S.Fd    := Cap.Server_Fd;
      Server_S.Index := Gneiss.Session_Index_Option'(Valid => True, Value => Idx);
      Server_S.E_Cap := Event_Cap (Server_S, Session, Server_S.Fd);
      Server_Instance.Initialize (Server_S, Ctx);
      if not Server_Instance.Ready (Server_S, Ctx) then
         Server_S.Index := Gneiss.Session_Index_Option'(Valid => False);
         Gneiss_Internal.Syscall.Close (Server_S.Fd);
         Gneiss_Internal.Invalidate (Server_S.E_Cap);
      end if;
   end Session_Initialize;

   procedure Session_Accept (Session  : in out Dispatcher_Session;
                             Cap      :        Dispatcher_Capability;
                             Server_S : in out Server_Session;
                             Ctx      :        Server_Instance.Context)
   is
      pragma Unreferenced (Ctx);
      Ignore_Success : Boolean;
   begin
      Gneiss_Internal.Epoll.Add (Session.Efd, Server_S.Fd, Server_Event_Address (Server_S), Ignore_Success);
      Gneiss_Internal.Client.Confirm (Session.Dispatch_Fd,
                                      Gneiss_Protocol.Session.Message,
                                      Cap.Name.Value (Cap.Name.Value'First .. Cap.Name.Last),
                                      Cap.Label.Value (Cap.Label.Value'First .. Cap.Label.Last),
                                      (1 => Cap.Client_Fd));
      Session.Accepted := True;
   end Session_Accept;

   procedure Session_Cleanup (Session  : in out Dispatcher_Session;
                              Cap      :        Dispatcher_Capability;
                              Server_S : in out Server_Session;
                              Ctx      : in out Server_Instance.Context)
   is
      use type Gneiss_Internal.File_Descriptor;
      Ignore_Success : Boolean;
   begin
      if
         Gneiss_Internal.Valid (Cap.Clean_Fd)
         and then Cap.Clean_Fd = Server_S.Fd
         and then Initialized (Server_S)
      then
         Gneiss_Internal.Epoll.Remove (Session.Efd, Server_S.Fd, Ignore_Success);
         Server_Instance.Finalize (Server_S, Ctx);
         Gneiss_Internal.Syscall.Close (Server_S.Fd);
         Server_S.Index := Gneiss.Session_Index_Option'(Valid => False);
         Gneiss_Internal.Invalidate (Server_S.E_Cap);
      end if;
   end Session_Cleanup;

end Gneiss.Message.Dispatcher;
