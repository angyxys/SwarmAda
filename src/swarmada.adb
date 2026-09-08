with GL;
with GLU;
with GLUT;
with GLUT.Devices;
with GLOBE_3D;
with GLOBE_3D.Math;
with GLOBE_3D.Textures;
with Ada.Text_IO;
with Ada.Exceptions;
with Lua_API;

procedure Swarmada is
   package G3D renames GLOBE_3D;
   package G3DM renames GLOBE_3D.Math;

   GLUT_Problem : exception;

   main_size_x, main_size_y : GL.Sizei;

   frontal_light : G3D.Light_definition;

   procedure Prepare_Lighting (fact : GL.Float) is
      use GL, G3D;
      proto_light : Light_definition :=
         (position => (3.0, 4.0, 10.0, 1.0),
          ambient  => (0.1, 0.1, 0.1, fact),
          diffuse  => (0.9, 0.9, 0.9, fact),
          specular => (0.05, 0.05, 0.01, fact));
   begin
      Enable (LIGHTING);
      G3D.Define (1, proto_light);
      frontal_light := proto_light;
      proto_light.diffuse := (0.5, 0.9, 0.5, fact);
      G3D.Define (2, proto_light);
      G3D.Switch_Light (1, True);
      G3D.Switch_Light (2, True);
   end Prepare_Lighting;

   procedure Clear_Modes is
      use GL;
   begin
      Disable (BLEND);
      Disable (LIGHTING);
      Disable (AUTO_NORMAL);
      Disable (NORMALIZE);
      Disable (DEPTH_TEST);
   end Clear_Modes;

   ego : G3D.Camera;
   deg2rad : constant := 3.1415926535897932 / 180.0;
   fairly_far : constant := 100.0;

   procedure Reset_For_3D (Width, Height : Integer) is
      use GL, G3D, G3D.REF;
      aspect, half_fov_max_rads, fovy : Real;
   begin
      Viewport (x => 0, y => 0, width => Sizei (Width), height => Sizei (Height));
      Set_Matrix_Mode (GL.PROJECTION);
      Load_Identity;
      aspect := GL.Double (Width) / GL.Double (Height);
      fovy := ego.FoVy;
      half_fov_max_rads := 0.5 * fovy * deg2rad;
      if aspect > 1.0 then
         half_fov_max_rads := Arctan (aspect * Tan (half_fov_max_rads));
      end if;
      ego.clipper.max_dot_product := Sin (half_fov_max_rads);
      ego.clipper.main_clipping := (0, 0, Width - 1, Height - 1);
      GLU.Perspective (fovy => fovy, aspect => aspect, zNear => 1.0, zFar => fairly_far);
      Set_Matrix_Mode (GL.MODELVIEW);
      Set_Shade_Model (GL.SMOOTH);
      Clear_Color (red_value => 0.0, green_value => 0.0, blue_value => 0.0, alpha_value => 0.0);
      Clear_Accumulation_Buffer (red_value => 0.0, green_value => 0.0, blue_value => 0.0, alpha_value => 0.0);
   end Reset_For_3D;

   procedure Window_Resize (Width, Height : Integer) is
   begin
      main_size_x := GL.Sizei (Width);
      main_size_y := GL.Sizei (Height);
      Reset_For_3D (Integer (main_size_x), Integer (main_size_y));
   end Window_Resize;

   procedure Menu (Value : Integer) is
   begin
      case Value is
         when 1 =>
            GLUT.FullScreen;
            GLUT.SetCursor (GLUT.CURSOR_NONE);
         when 2 =>
            GLUT.LeaveMainLoop;
         when others =>
            null;
      end case;
   end Menu;

   --  DECLARADO ALIASED
   Cube : aliased G3D.Object_3D (Max_Points => 8, Max_Faces => 6);

   procedure Create_Objects is
      t : constant := 1.0;
      use GL, G3D, G3D.Textures;

      function Basic_Face
         (P        : G3D.Index_Array;
          Tex_Name : String;
          Colour   : GL.RGB_Color;
          Repeat   : Positive)
          return Face_Type
      is
         f : Face_Type;
      begin
         f.P := P;
         --  Usamos Colour_Only para evitar texturas externas
         f.skin := Colour_Only;
         f.colour := Colour;
         f.alpha := 1.0;
         f.repeat_U := Repeat;
         f.repeat_V := Repeat;
         return f;
      end Basic_Face;
   begin
      Cube.centre := (0.0, 0.0, 0.0);
      Cube.Point :=
         ((-t, -t, -t), (-t, t, -t), (t, t, -t), (t, -t, -t),
          (-t, -t,  t), (-t,  t,  t), ( t,  t,  t), ( t, -t,  t));
      Cube.Face :=
         (Basic_Face ((3, 2, 6, 7), "", (1.0, 0.0, 0.0), 1),
          Basic_Face ((4, 3, 7, 8), "", (0.0, 1.0, 0.0), 2),
          Basic_Face ((8, 7, 6, 5), "", (0.0, 0.0, 1.0), 3),
          Basic_Face ((1, 4, 8, 5), "", (1.0, 1.0, 0.0), 4),
          Basic_Face ((2, 1, 5, 6), "", (0.0, 1.0, 1.0), 5),
          Basic_Face ((3, 4, 1, 2), "", (1.0, 0.0, 1.0), 6));
      Set_Name (Cube, "Trust the Cube !");
   end Create_Objects;

   procedure Display_Scene (O : in out G3D.Object_3D'Class) is
      use GL, G3D, G3D.REF, G3DM;
   begin
      Clear (DEPTH_BUFFER_BIT);
      Disable (LIGHTING);
      Enable (DEPTH_TEST);
      Set_Matrix_Mode (GL.MODELVIEW);
      Set_GL_Matrix (ego.world_rotation);
      Enable (LIGHTING);
      Enable (CULL_FACE);
      Set_Cull_Face (BACK);
      GL.Translate (-ego.clipper.eye_position (0),
                    -ego.clipper.eye_position (1),
                    -ego.clipper.eye_position (2));

      Push_Matrix;
      G3D.Display (O, ego.clipper);
      Pop_Matrix;
   end Display_Scene;

   last_time : Integer;
   new_scene : Boolean := True;

   procedure Fill_Screen is
      use GL;
   begin
      Clear (COLOR_BUFFER_BIT);
      Display_Scene (Cube);
      GLUT.SwapBuffers;
   end Fill_Screen;

   procedure Reset_Eye is
   begin
      ego.clipper.eye_position := (0.0, 0.0, 4.0);
      ego.world_rotation := G3D.Id_33;
   end Reset_Eye;

   procedure Main_Operations is
      use GL, G3D, G3DM, G3D.REF;
      elaps, time_now : Integer;
   begin
      time_now := GLUT.Get (GLUT.ELAPSED_TIME);

      if new_scene then
         new_scene := False;
         elaps := 0;
      else
         elaps := time_now - last_time;
      end if;
      last_time := time_now;

      --  Actualizar desde Lua
      Lua_API.Update (Float (elaps) * 0.001);
      Ada.Text_IO.Put_Line ("Posición del cubo: " & 
          Float'Image (Float (Cube.centre (0))) & ", " &
          Float'Image (Float (Cube.centre (1))) & ", " &
          Float'Image (Float (Cube.centre (2))));

      ego.clipper.view_direction := Transpose (ego.world_rotation) * (0.0, 0.0, -1.0);

      frontal_light.position :=
        (GL.Float (ego.clipper.eye_position (0)),
         GL.Float (ego.clipper.eye_position (1)),
         GL.Float (ego.clipper.eye_position (2)),
         1.0);
      G3D.Define (1, frontal_light);

      Fill_Screen;

      if GLUT.Devices.Strike_Once (Character'Val (27)) then
         GLUT.LeaveMainLoop;
      end if;
   end Main_Operations;

   procedure Start_GLUTs is
      use GLUT;
   begin
      Init;
      InitDisplayMode (GLUT.DOUBLE or GLUT.RGB or GLUT.DEPTH);
      main_size_x := 800;
      main_size_y := 600;
      InitWindowSize (Integer (main_size_x), Integer (main_size_y));
      InitWindowPosition (120, 120);
      if CreateWindow ("SwarmAda - GLOBE_3D Demo") = 0 then
         raise GLUT_Problem;
      end if;
      ReshapeFunc (Window_Resize'Address);
      DisplayFunc (Main_Operations'Address);
      IdleFunc (Main_Operations'Address);
      GLUT.Devices.Initialize;

      if CreateMenu (Menu'Address) = 0 then
         raise GLUT_Problem;
      end if;
      AttachMenu (MIDDLE_BUTTON);
      AddMenuEntry (" * Full Screen", 1);
      AddMenuEntry ("--> Exit (Esc)", 2);
   end Start_GLUTs;

   procedure Start_GLs is
      use GL;
   begin
      Clear_Modes;
      Prepare_Lighting (0.9);
      Reset_For_3D (Integer (main_size_x), Integer (main_size_y));
   end Start_GLs;

begin
   Ada.Text_IO.Put_Line ("Iniciando...");
   Ada.Text_IO.Put_Line ("Configurando datos globales...");
   G3D.Set_Global_Data_Name ("g3demo_global_resources.zip");
   Ada.Text_IO.Put_Line ("Registrando texturas...");
   G3D.Textures.Register_Textures_From_Resources;

   Ada.Text_IO.Put_Line ("Creando objetos...");
   Create_Objects;

   --  Inicializar Lua
   Ada.Text_IO.Put_Line ("Inicializando Lua...");
   Lua_API.Initialize (Cube'Unchecked_Access);
   Lua_API.Load_Script ("scripts/mover.lua");

   Ada.Text_IO.Put_Line ("Iniciando GLUTs...");
   Start_GLUTs;
   Ada.Text_IO.Put_Line ("Iniciando GLs...");
   Start_GLs;
   Ada.Text_IO.Put_Line ("Reset eye...");
   Reset_Eye;

   Ada.Text_IO.Put_Line ("Precargando texturas...");
   G3D.Textures.Check_All_Textures;

   Ada.Text_IO.Put_Line ("Entrando en Main_Loop...");
   GLUT.MainLoop;

exception
   when E : others =>
      Ada.Text_IO.Put_Line ("Excepción capturada: " & Ada.Exceptions.Exception_Name (E));
      Ada.Text_IO.Put_Line ("Mensaje: " & Ada.Exceptions.Exception_Message (E));
end Swarmada;
