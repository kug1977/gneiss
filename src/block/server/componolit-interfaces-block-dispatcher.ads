--
--  @summary Block dispatcher interface
--  @author  Johannes Kliemann
--  @date    2019-04-10
--
--  Copyright (C) 2019 Componolit GmbH
--
--  This file is part of ada-interface, which is distributed under the terms of the
--  GNU Affero General Public License version 3.
--

with Componolit.Interfaces.Types;
with Componolit.Interfaces.Block.Server;

pragma Warnings (Off);
--  Supress unreferenced warnings since not every platform needs each subprogram/package

generic
   --  Server implementation to be registered
   with package Serv is new Componolit.Interfaces.Block.Server (<>);

   --  Called when a client connects or disconnects
   with procedure Dispatch (Cap : Dispatcher_Capability);

   pragma Warnings (On);
package Componolit.Interfaces.Block.Dispatcher with
   SPARK_Mode
is

   --  Checks if D is initialized
   --
   --  @param D  Dispatcher session instance
   function Initialized (D : Dispatcher_Session) return Boolean;

   --  Create new dispatcher session
   --
   --  @return Uninitialized dispatcher session
   function Create return Dispatcher_Session with
      Post => not Initialized (Create'Result);

   --  Return the instance ID of D
   --
   --  @param D  Dispatcher session instance
   function Instance (D : Dispatcher_Session) return Dispatcher_Instance with
      Pre => Initialized (D);

   --  Initialize dispatcher session with the system capability Cap
   --
   --  @param D    Dispatcher session instance
   --  @param Cap  System capability
   procedure Initialize (D   : in out Dispatcher_Session;
                         Cap :        Componolit.Interfaces.Types.Capability);

   --  Register the server implementation Serv on the platform
   --
   --  @param D  Dispatcher session instance
   procedure Register (D : in out Dispatcher_Session) with
      Pre  => Initialized (D),
      Post => Initialized (D);

   --  Finalize dispatcher session
   --
   --  @param D  Dispatcher session instance
   procedure Finalize (D : in out Dispatcher_Session) with
      Pre  => Initialized (D),
      Post => not Initialized (D);

   --  Check if the passed dispatcher capability contains a valid session request
   --
   --  @param D  Dispatcher session instance
   --  @param C  Unique capability for this session request
   --  @return   Dispatcher capability contains a valid request
   function Valid_Session_Request (D : Dispatcher_Session;
                                   C : Dispatcher_Capability) return Boolean with
      Pre => Initialized (D);

   --  Initialize session that should accept the request
   --
   --  It initializes the server on the platform and calls Serv.Initialize.
   --
   --  @param D  Dispatcher session instance
   --  @param C  Unique capability for this session request
   --  @param I  Server session instance to be initialized
   procedure Session_Initialize (D : in out Dispatcher_Session;
                                 C :        Dispatcher_Capability;
                                 I : in out Server_Session) with
      Pre  => Initialized (D)
              and then Valid_Session_Request (D, C)
              and then not Serv.Initialized (I),
      Post => Initialized (D);

   --  Accept session request
   --
   --  @param D  Dispatcher session instance
   --  @param C  Unique capability for this session request
   --  @param I  Server session instance to handle client connection with
   procedure Session_Accept (D : in out Dispatcher_Session;
                             C :        Dispatcher_Capability;
                             I : in out Server_Session) with
      Pre  => Initialized (D)
              and then Valid_Session_Request (D, C)
              and then Serv.Initialized (I),
      Post => Initialized (D);

   --  Garbage collects disconnected sessions
   --
   --  This procedure must only be used in Dispatch.
   --  It should be called on each session each time Dispatch is called.
   --  Server_Session will be finalized if the client disconnected on the platform.
   --
   --  @param D  Dispatcher session instance
   --  @param C  Unique capability for this session request
   --  @param I  Server session instance to check for removal
   procedure Session_Cleanup (D : in out Dispatcher_Session;
                              C :        Dispatcher_Capability;
                              I : in out Server_Session) with
      Pre  => Initialized (D),
      Post => Initialized (D);

end Componolit.Interfaces.Block.Dispatcher;
