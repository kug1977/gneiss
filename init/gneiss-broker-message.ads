
with RFLX.Types;
private with Gneiss_Syscall;
private with RFLX.Session;
private with RFLX.Session.Packet;

package Gneiss.Broker.Message with
   SPARK_Mode
is

   procedure Read_Message (State  :        Broker_State;
                           Index  :        Positive;
                           Buffer : in out RFLX.Types.Bytes_Ptr);

private

   type RFLX_String is array (RFLX.Session.Length_Type range <>) of Character;

   function Convert_Message (S : String) return RFLX_String;

   procedure Load_Message (State   : Broker_State;
                           Index   : Positive;
                           Context : RFLX.Session.Packet.Context;
                           Fds     : Gneiss_Syscall.Fd_Array);

   procedure Handle_Message (State  : Broker_State;
                             Source : Positive;
                             Action : RFLX.Session.Action_Type;
                             Kind   : RFLX.Session.Kind_Type;
                             Name   : String;
                             Label  : String;
                             Fds    : Gneiss_Syscall.Fd_Array);

   procedure Process_Request (State  : Broker_State;
                              Source : Positive;
                              Kind   : RFLX.Session.Kind_Type;
                              Label  : String;
                              Fds    : Gneiss_Syscall.Fd_Array);

   procedure Process_Message_Request (Fds   : out Gneiss_Syscall.Fd_Array;
                                      Valid : out Boolean);

   procedure Process_Rom_Request (State       :     Broker_State;
                                  Serv_State  :     SXML.Query.State_Type;
                                  Fds         : out Gneiss_Syscall.Fd_Array;
                                  Valid       : out Boolean);

   procedure Process_Confirm (State : Broker_State;
                              Kind  : RFLX.Session.Kind_Type;
                              Name  : String;
                              Label : String;
                              Fds   : Gneiss_Syscall.Fd_Array);

   procedure Process_Reject (State : Broker_State;
                             Kind  : RFLX.Session.Kind_Type;
                             Name  : String;
                             Label : String);

   procedure Send_Request (Destination : Integer;
                           Kind        : RFLX.Session.Kind_Type;
                           Name        : String;
                           Label       : String;
                           Fds         : Gneiss_Syscall.Fd_Array);

   procedure Send_Confirm (Destination : Integer;
                           Kind        : RFLX.Session.Kind_Type;
                           Label       : String;
                           Fds         : Gneiss_Syscall.Fd_Array);

   procedure Send_Reject (Destination : Integer;
                          Kind        : RFLX.Session.Kind_Type;
                          Label       : String);
end Gneiss.Broker.Message;
