
with Cxx;
with Cxx.Log.Client;

package Componolit.Interfaces.Internal.Log is

   type Client_Session is limited record
      Instance : Cxx.Log.Client.Class := Cxx.Log.Client.Constructor;
   end record;

end Componolit.Interfaces.Internal.Log;
