with GLOBE_3D;
with Lua;

package Lua_API is
   procedure Initialize (Cube: access GLOBE_3D.Object_3D'Class);

   procedure Load_Script (Filename : String);

   procedure Update (Delta_Time : Float);

   function GeT_State return Lua.Lua_State;
private
   Update_Ref : Lua.Lua_Index := 0;
end Lua_API;
