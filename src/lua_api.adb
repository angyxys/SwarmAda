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
            Dummy : Integer := Error (L);
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
   end Initialize;

   procedure Load_Script (Filename : String) is
      Res : Lua_Return_Code;
      Top : Lua_Index;
      Kind : Lua_Type;
   begin
      Res := Load_File (State, Filename);
      if Res /= LUA_OK then
         declare
            Msg : constant String := To_Ada (State, -1);
         begin
            Pop (State);
            Put_Line ("Failed to load script: " & Msg);
         end;
      else
         if PCall (State, 0, 1, 0, 0, null) /= LUA_OK then
            declare
               Msg : constant String := To_Ada (State, -1);
            begin
               Pop (State);
               Put_Line ("Failed to run script: " & Msg);
            end;
         else
            Top := Get_Top (State);
            Kind := Get_Type (State, Top);
            if Kind = LUA_TFUNCTION then
               Update_Ref := Top;
            else
               Pop (State);
            end if;
         end if;
      end if;
   end Load_Script;

   procedure Update (Delta_Time : Float) is
   begin
      if Update_Ref = 0 then
         return;
      end if;

      if Get_Type (State, Update_Ref) = LUA_TFUNCTION then
         Push_Value (State, Update_Ref);
         Push (State, Lua_Float (Delta_Time));
         if PCall (State, 1, 0, 0) /= LUA_OK then
            declare
               Msg : constant String := To_Ada (State, -1);
            begin
               Pop (State);
               Put_Line ("Error running update: " & Msg);
            end;
         end if;
      else
         Update_Ref := 0;
      end if;
   end Update;

   function Get_State return Lua_State is
   begin
      return State;
   end Get_State;

end Lua_API;
