using System;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Forms;

namespace GUI2
{
    public partial class SettingsWindow : Window
    {
        private ConfigModels config;
        private string configPath;
        private string logFilePath;

        public SettingsWindow()
        {
            InitializeComponent();
            InitializeLogging();
            LoadCurrentSettings();
        }

        private void InitializeLogging()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string appFolderPath = Path.Combine(appDataPath, "DriverPackFetcher");
            Directory.CreateDirectory(appFolderPath);
            logFilePath = Path.Combine(appFolderPath, "Settings-log.txt");
            File.WriteAllText(logFilePath, "Log started at " + DateTime.Now + Environment.NewLine);
        }

        private void Log(string message)
        {
            File.AppendAllText(logFilePath, DateTime.Now + ": " + message + Environment.NewLine);
        }

        private void LoadCurrentSettings()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string appFolderPath = Path.Combine(appDataPath, "DriverPackFetcher");
            Directory.CreateDirectory(appFolderPath);
            configPath = Path.Combine(appFolderPath, "config.json");

            if (File.Exists(configPath))
            {
                string json = File.ReadAllText(configPath);
                config = JsonSerializer.Deserialize<ConfigModels>(json);
                Log($"Loaded existing config.json from app data: {json}");

                hpLocalPath.Text = config.HP.LocalPath;
                lenovoNetworkPath.Text = config.Lenovo.NetworkPath;
                dellNetworkPath.Text = config.Dell.NetworkPath;
            }
            else
            {
                // Create a new config if it doesn't exist
                config = new ConfigModels
                {
                    HP = new HP { LocalPath = "C:\\HP-Drivers", NetworkPath = "%USERPROFILE%\\Documents\\LocalHP", PowerShellExe = "C:\\Program Files\\PowerShell\\7\\pwsh.exe", DriverScriptName = "HP-Drivers.ps1" },
                    Lenovo = new Lenovo { DriverScriptName = "Lenovo-Drivers.ps1", DownloadPath = "%USERPROFILE%\\Downloads\\.Lenovo", NetworkPath = "%USERPROFILE%\\Documents\\LocalLenovo", CatalogPath = ".\\Resources\\LenovoDriverPackCatalog.xml", DaysToRefresh = 40 },
                    Dell = new Dell { DriverScriptName = "Dell-Drivers.ps1", DownloadPath = "C:\\Path\\To\\Dell\\Downloads", NetworkPath = "%USERPROFILE%\\Documents\\LocalDell" }
                };
                Log("Created new config with default values.");
            }
        }

        private void BrowseHpLocalPath_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var dialog = new FolderBrowserDialog())
                {
                    if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        hpLocalPath.Text = dialog.SelectedPath;
                        Log("HP local path selected: " + dialog.SelectedPath);
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Error selecting HP local path: " + ex.Message);
                System.Windows.MessageBox.Show($"Error selecting HP local path: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BrowseLenovoNetworkPath_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var dialog = new FolderBrowserDialog())
                {
                    if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        lenovoNetworkPath.Text = dialog.SelectedPath;
                        Log("Lenovo network path selected: " + dialog.SelectedPath);
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Error selecting Lenovo network path: " + ex.Message);
                System.Windows.MessageBox.Show($"Error selecting Lenovo network path: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BrowseDellNetworkPath_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var dialog = new FolderBrowserDialog())
                {
                    if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
                    {
                        dellNetworkPath.Text = dialog.SelectedPath;
                        Log("Dell network path selected: " + dialog.SelectedPath);
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Error selecting Dell network path: " + ex.Message);
                System.Windows.MessageBox.Show($"Error selecting Dell network path: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                config.HP.LocalPath = hpLocalPath.Text;
                config.Lenovo.NetworkPath = lenovoNetworkPath.Text;
                config.Dell.NetworkPath = dellNetworkPath.Text;

                string json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(configPath, json);
                Log("Saved config.json: " + json);
                System.Windows.MessageBox.Show("Settings saved successfully.", "Info", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                Log("Error saving config.json: " + ex.Message);
                System.Windows.MessageBox.Show($"Error saving settings: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
