--
--  @summary Gneiss top package
--  @author  Johannes Kliemann
--  @date    2019-04-10
--
--  Copyright (C) 2019 Componolit GmbH
--
--  This file is part of Gneiss, which is distributed under the terms of the
--  GNU Affero General Public License version 3.
--

package Gneiss with
   SPARK_Mode
is

   type Session_Status is (Uninitialized, Pending, Initialized);

end Gneiss;