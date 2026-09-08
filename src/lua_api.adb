with Ada.Text_IO;
with GLOBE_3D;
with GLOBE_3D.Math;
with Lua; use Lua;

package body Lua_API is

   use Ada.Text_IO;

   State : Lua_State;
   Cube_Ptr : access GLOBE_3D.Object_3D'Class;

   function Get_Cube_Position return GLOBE_3D.Vector_3D is
   begin
      return Cube_Ptr.Centre;
   end Get_Cube_Position;

   procedure Set_Cube_Position (Pos : GLOBE_3D.Vector_3D) is
   begin
      Cube_Ptr.Centre := Pos;
   end Set_Cube_Position;

   procedure Set_Cube_Rotation (X, Y, Z : Float) is
      use GLOBE_3D.Math;
   begin
      Cube_Ptr.Rotation := XYZ_Rotation (GLOBE_3D.Real (X),
                                         GLOBE_3D.Real (Y),
                                         GLOBE_3D.Real (Z));
   end Set_Cube_Rotation;

   function Get_Number (L : Lua_State; Index : Lua_Index) return Lua_Float is
   begin
      if not Is_Number (L, Index) then
         Push (L, "expected number");
         declare
            Dummy : Integer := Error (L);  --  no retorna
         begin
            return 0.0;
         end;
      end if;
      return To_Ada (L, Index);
   end Get_Number;

   function Get_Position_Wrapper (L : Lua_State) return Integer;
   pragma Convention (C, Get_Position_Wrapper);

   function Set_Position_Wrapper (L : Lua_State) return Integer;
   pragma Convention (C, Set_Position_Wrapper);

   function Set_Rotation_Wrapper (L : Lua_State) return Integer;
   pragma Convention (C, Set_Rotation_Wrapper);

   function Get_Position_Wrapper (L : Lua_State) return Integer is
      Pos : constant GLOBE_3D.Vector_3D := Get_Cube_Position;
   begin
      Push (L, Lua_Float (Pos (0)));
      Push (L, Lua_Float (Pos (1)));
      Push (L, Lua_Float (Pos (2)));
      return 3;
   end Get_Position_Wrapper;

   function Set_Position_Wrapper (L : Lua_State) return Integer is
      X : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 1));
      Y : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 2));
      Z : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 3));
   begin
      Set_Cube_Position ((X, Y, Z));
      return 0;
   end Set_Position_Wrapper;

   function Set_Rotation_Wrapper (L : Lua_State) return Integer is
      X : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 1));
      Y : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 2));
      Z : constant GLOBE_3D.Real := GLOBE_3D.Real (Get_Number (L, 3));
   begin
      Set_Cube_Rotation (Float (X), Float (Y), Float (Z));
      return 0;
   end Set_Rotation_Wrapper;

   procedure Initialize (Cube : access GLOBE_3D.Object_3D'Class) is
   begin
      Cube_Ptr := Cube;
      State := New_State;
      Open_Libs (State);

      Register_Function (State, "get_position", Get_Position_Wrapper'Access);
      Register_Function (State, "set_position", Set_Position_Wrapper'Access);
      Register_Function (State, "set_rotation", Set_Rotation_Wrapper'Access);

      Put_Line ("Lua inicializado correctamente.");
   end Initialize;

   procedure Load_Script (Filename : String) is
      Res : Lua_Return_Code;
      Top : Lua_Index;
      Tipo : Lua_Type;
   begin
      Res := Load_File (State, Filename);
      if Res /= LUA_OK then
         declare
            Msg : constant String := To_Ada (State, -1);
         begin
            Pop (State);
            Put_Line ("Error al cargar script: " & Msg);
         end;
      else
         Put_Line ("Script cargado correctamente. Ejecutando...");
         if PCall (State, 0, 1, 0, 0, null) /= LUA_OK then
            declare
               Msg : constant String := To_Ada (State, -1);
            begin
               Pop (State);
               Put_Line ("Error al ejecutar script: " & Msg);
            end;
         else
            Put_Line ("Script ejecutado correctamente.");
            Top := Get_Top (State);
            Tipo := Get_Type (State, Top);
            Put_Line ("Valor devuelto - Tipo: " & Lua_Type'Image (Tipo));
            if Tipo = LUA_TFUNCTION then
               Put_Line ("Es una función, guardando referencia...");
               --  Guardar la referencia en la pila
               Update_Ref := Top;
               Put_Line ("Referencia guardada en Update_Ref=" & Integer'Image (Update_Ref));
            else
               Put_Line ("El valor devuelto NO es una función. Descartando...");
               Pop (State);
            end if;
         end if;
      end if;
   end Load_Script;

   procedure Update (Delta_Time : Float) is
   begin
      if Update_Ref = 0 then
         Put_Line ("Update_Ref no inicializada");
         return;
      end if;

      --  Verificar que la función sigue en la pila
      if Get_Type (State, Update_Ref) = LUA_TFUNCTION then
         --  Empujar la función a la cima (si no está ya)
         Push_Value (State, Update_Ref);
         Push (State, Lua_Float (Delta_Time));
         if PCall (State, 1, 0, 0) /= LUA_OK then
            declare
               Msg : constant String := To_Ada (State, -1);
            begin
               Pop (State);
               Put_Line ("Error al ejecutar update: " & Msg);
            end;
         end if;
      else
         Put_Line ("La referencia a update ya no es válida");
         Update_Ref := 0;
      end if;
   end Update;

   function Get_State return Lua_State is
   begin
      return State;
   end Get_State;

end Lua_API;
