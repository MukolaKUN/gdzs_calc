GDZS pressure input fix

1. Extract this archive.
2. Stop the running Flutter app with Ctrl+C.
3. Run from PowerShell:

powershell -ExecutionPolicy Bypass -File .\apply_fix.ps1 -ProjectPath D:\gdzs_calc

4. After successful analyze and tests, run:

cd D:\gdzs_calc
flutter run
