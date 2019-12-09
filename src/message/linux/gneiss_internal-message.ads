
with Gneiss_Epoll;
with Gneiss_Platform;

package Gneiss_Internal.Message with
   SPARK_Mode
is
   use type Gneiss_Epoll.Epoll_Fd;

   type Client_Session is record
      File_Descriptor : Integer := -1;
      Epoll_Fd        : Gneiss_Epoll.Epoll_Fd := -1;
      Label           : Session_Label;
   end record;

   type Server_Session is record
      Fd : Integer := -1;
   end record;

   type Dispatcher_Session is record
      Register_Service : Gneiss_Platform.Register_Service_Cap;
      Client_Fd        : Integer := -1;
      Accepted         : Boolean := False;
   end record;

   type Dispatcher_Capability is limited record
      Clean_Fd : Integer := -1;
   end record;

end Gneiss_Internal.Message;