using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;

namespace GUI2
{
    public partial class MainWindow : Window
    {
        private Process powerShellProcess;
        private ConfigModels config;

        public MainWindow()
        {
            InitializeComponent();
            this.Closing += new System.ComponentModel.CancelEventHandler(Window_Closing);
            LoadConfiguration();
            SetupConfigurationWatcher();
        }

        private string configPath; // Globaali muuttuja konfiguraation polulle

        public void LoadConfiguration()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string appFolderPath = Path.Combine(appDataPath, "DriverPackFetcher");
            configPath = Path.Combine(appFolderPath, "config.json");

            if (!File.Exists(configPath))
            {
                configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Resources", "config.json");
            }

            try
            {
                string json = File.ReadAllText(configPath);
                config = JsonSerializer.Deserialize<ConfigModels>(json);

                if (config == null)
                {
                    throw new Exception("Failed to deserialize configuration file.");
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error loading configuration: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private FileSystemWatcher configWatcher;

        private void SetupConfigurationWatcher()
        {
            string appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string appFolderPath = Path.Combine(appDataPath, "DriverPackFetcher");

            configWatcher = new FileSystemWatcher(appFolderPath, "config.json")
            {
                NotifyFilter = NotifyFilters.LastWrite
            };

            configWatcher.Changed += OnConfigurationChanged;
            configWatcher.EnableRaisingEvents = true;
        }

        private void OnConfigurationChanged(object sender, FileSystemEventArgs e)
        {
            // Ensure we handle only single event.
            configWatcher.EnableRaisingEvents = false;
            try
            {
                // This delay ensures that file is fully released by another process.
                Task.Delay(500).Wait();
                LoadConfiguration();
            }
            finally
            {
                configWatcher.EnableRaisingEvents = true;
            }
        }

        private string GetConfigValue(string section, string key)
        {
            var sectionProperty = typeof(ConfigModels).GetProperty(section);
            if (sectionProperty != null)
            {
                var sectionValue = sectionProperty.GetValue(config);
                if (sectionValue != null)
                {
                    var keyProperty = sectionValue.GetType().GetProperty(key);
                    if (keyProperty != null)
                    {
                        var value = keyProperty.GetValue(sectionValue);
                        return value?.ToString();
                    }
                }
            }
            throw new Exception($"Configuration key '{key}' not found in section '{section}'.");
        }

        private void ModelNameTextBox_GotFocus(object sender, RoutedEventArgs e)
        {
            if (modelNameTextBox.Text == "Syötä mallin nimi")
            {
                modelNameTextBox.Text = "";
                modelNameTextBox.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#cba6f7"));
            }
        }

        private void ModelNameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(modelNameTextBox.Text))
            {
                modelNameTextBox.Text = "Syötä mallin nimi";
                modelNameTextBox.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#cba6f7"));
            }
        }

        private void ModelType_Checked(object sender, RoutedEventArgs e)
        {
            if (radioButtonSingleModel.IsChecked == true)
            {
                modelNameTextBox.Visibility = Visibility.Visible;
            }
            else
            {
                modelNameTextBox.Visibility = Visibility.Collapsed;
            }
        }

        private void RadioButton_Checked(object sender, RoutedEventArgs e)
        {
            RadioButton radioButton = sender as RadioButton;

            if (radioButton != null)
            {
                if (radioButton.Name == "radioButtonLenovo")
                {
                    AppendOutput("Lenovo selected");
                }
                else if (radioButton.Name == "radioButtonDell")
                {
                    AppendOutput("Dell selected");
                }
                else if (radioButton.Name == "radioButtonHP")
                {
                    AppendOutput("HP selected");
                }
            }
        }

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string sectionName = null;
            string driverScriptName = null;
            string modelName = null;
            string csvPath = null;
            bool includeFirmware = false;

            // Access UI elements using Dispatcher.Invoke
            Dispatcher.Invoke(() =>
            {
                if (radioButtonLenovo.IsChecked == true)
                {
                    sectionName = "Lenovo";
                }
                else if (radioButtonDell.IsChecked == true)
                {
                    sectionName = "Dell";
                }
                else if (radioButtonHP.IsChecked == true)
                {
                    sectionName = "HP";
                }

                try
                {
                    driverScriptName = GetConfigValue(sectionName, "DriverScriptName");
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Error reading script names: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }

                modelName = radioButtonSingleModel.IsChecked == true ? modelNameTextBox.Text : null;
                includeFirmware = checkBoxFirmware.IsChecked == true;
            });

            if (radioButtonCsvModel.IsChecked == true)
            {
                Dispatcher.Invoke(() =>
                {
                    OpenFileDialog openFileDialog = new OpenFileDialog
                    {
                        Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
                    };

                    if (openFileDialog.ShowDialog() == true)
                    {
                        csvPath = openFileDialog.FileName;
                    }
                    else
                    {
                        MessageBox.Show("CSV file selection cancelled.", "Info", MessageBoxButton.OK, MessageBoxImage.Information);
                        return;
                    }
                });
            }

            HideInputElements();
            outputTextBox.Visibility = Visibility.Visible;

            string driverDownloadPath = Path.Combine(Path.GetTempPath(), $"{sectionName}Drivers");
            string networkPath = GetConfigValue(sectionName, "NetworkPath");

            // Run driver script
            await Task.Run(() => RunPowerShellScript(driverScriptName, modelName, driverDownloadPath, networkPath, csvPath, includeFirmware));
        }

        private void SettingsButton_Click(object sender, RoutedEventArgs e)
        {
            // Luodaan uusi instanssi SettingsWindow-luokasta
            SettingsWindow settingsWindow = new SettingsWindow();

            // Näytetään SettingsWindow käyttäjälle.
            // Käytä ShowDialog()m ikkuna on modaali (käyttäjä ei voi käyttää muita sovelluksen ikkunoita ennen tämän sulkemista).

            settingsWindow.ShowDialog();
        }

        private void HideInputElements()
        {
            radioButtonLenovo.Visibility = Visibility.Collapsed;
            radioButtonDell.Visibility = Visibility.Collapsed;
            radioButtonHP.Visibility = Visibility.Collapsed;
            radioButtonSingleModel.Visibility = Visibility.Collapsed;
            radioButtonCsvModel.Visibility = Visibility.Collapsed;
            modelNameTextBox.Visibility = Visibility.Collapsed;
            checkBoxFirmware.Visibility = Visibility.Collapsed;
            searchButton.Visibility = Visibility.Collapsed;
            settingsButton.Visibility = Visibility.Collapsed; // Hide settings button
            resetButton.Visibility = Visibility.Visible; // Show reset button
            outputTextBox.Visibility = Visibility.Visible; // Show output text box
        }

        private void RunPowerShellScript(string scriptName, string modelName, string downloadPath, string networkPath, string csvPath, bool includeFirmware)
        {
            string tempScriptPath = Path.Combine(Path.GetTempPath(), scriptName);

            try
            {
                string scriptContent = GetEmbeddedResource($"GUI2.Resources.{scriptName}");

                if (string.IsNullOrEmpty(scriptContent))
                {
                    MessageBox.Show("Script content is empty or not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }

                using (StreamWriter writer = new StreamWriter(tempScriptPath, false, new UTF8Encoding(true))) // Ensure BOM
                {
                    writer.Write(scriptContent);
                }
                AppendOutput($"Script written to {tempScriptPath}");

                string arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\" -ModelName \"{modelName}\" -DownloadPath \"{downloadPath}\" -NetworkPath \"{networkPath}\" -ConfigPath \"{configPath}\" -Option 1";
                if (!string.IsNullOrEmpty(csvPath))
                {
                    arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\" -CsvPath \"{csvPath}\" -DownloadPath \"{downloadPath}\" -NetworkPath \"{networkPath}\" -ConfigPath \"{configPath}\" -Option 2";
                }
                if (includeFirmware)
                {
                    arguments += " -IncludeFirmware";
                }

                AppendOutput($"Running script with arguments: {arguments}");

                using (Process powerShellProcess = new Process())
                {
                    powerShellProcess.StartInfo = new ProcessStartInfo()
                    {
                        FileName = "powershell.exe", // Example path to PowerShell executable
                        Arguments = arguments,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        StandardOutputEncoding = Encoding.UTF8,
                        StandardErrorEncoding = Encoding.UTF8,
                        UseShellExecute = false,
                        CreateNoWindow = true
                    };

                    powerShellProcess.OutputDataReceived += (s, e) => AppendOutput(e.Data);
                    powerShellProcess.ErrorDataReceived += (s, e) => AppendOutput(e.Data);

                    powerShellProcess.Start();
                    powerShellProcess.BeginOutputReadLine();
                    powerShellProcess.BeginErrorReadLine();
                    powerShellProcess.WaitForExit();

                    AppendOutput($"Process exited with code: {powerShellProcess.ExitCode}");
                    if (powerShellProcess.ExitCode != 0)
                    {
                        AppendOutput($"Error occurred while running PowerShell script. Exit code: {powerShellProcess.ExitCode}");
                    }
                }
            }
            catch (Exception ex)
            {
                AppendOutput($"Error: {ex.Message}");
            }
            finally
            {
                if (File.Exists(tempScriptPath))
                {
                    File.Delete(tempScriptPath);
                    AppendOutput($"Deleted temp script: {tempScriptPath}");
                }
            }
        }

        private void AppendOutput(string data)
        {
            if (data != null)
            {
                Dispatcher.Invoke(() =>
                {
                    outputTextBox.AppendText(data + Environment.NewLine);
                    outputTextBox.ScrollToEnd();
                });
            }
        }

        private string GetEmbeddedResource(string resourceName)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            string[] resourceNames = assembly.GetManifestResourceNames();
            foreach (string resource in resourceNames)
            {
                if (resource.EndsWith(resourceName, StringComparison.OrdinalIgnoreCase))
                {
                    using (Stream stream = assembly.GetManifestResourceStream(resource))
                    {
                        if (stream != null)
                        {
                            using (StreamReader reader = new StreamReader(stream))
                            {
                                return reader.ReadToEnd();
                            }
                        }
                    }
                }
            }
            return null;
        }

        private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (powerShellProcess != null && !powerShellProcess.HasExited)
            {
                try
                {
                    powerShellProcess.Kill();
                    powerShellProcess.WaitForExit();
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Error while closing PowerShell process: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                finally
                {
                    powerShellProcess?.Dispose();
                    powerShellProcess = null;
                }
            }
        }

        private async void ResetButton_Click(object sender, RoutedEventArgs e)
        {
            if (powerShellProcess != null && !powerShellProcess.HasExited)
            {
                try
                {
                    powerShellProcess.Kill();
                    await Task.Run(() => powerShellProcess.WaitForExit());
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Error while terminating PowerShell process: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                finally
                {
                    powerShellProcess?.Dispose();
                    powerShellProcess = null;
                }
            }

            ResetUI();
        }

        private void ResetUI()
        {
            // Reset UI elements to their default state
            radioButtonLenovo.Visibility = Visibility.Visible;
            radioButtonDell.Visibility = Visibility.Visible;
            radioButtonHP.Visibility = Visibility.Visible;
            radioButtonSingleModel.Visibility = Visibility.Visible;
            radioButtonCsvModel.Visibility = Visibility.Visible;
            modelNameTextBox.Visibility = Visibility.Visible;
            checkBoxFirmware.Visibility = Visibility.Visible;
            searchButton.Visibility = Visibility.Visible;
            settingsButton.Visibility = Visibility.Visible; // Show settings button
            resetButton.Visibility = Visibility.Collapsed;
            outputTextBox.Visibility = Visibility.Collapsed;

            radioButtonLenovo.IsChecked = false;
            radioButtonDell.IsChecked = false;
            radioButtonHP.IsChecked = false;
            radioButtonSingleModel.IsChecked = false;
            radioButtonCsvModel.IsChecked = false;
            modelNameTextBox.Text = "Syötä mallin nimi";
            checkBoxFirmware.IsChecked = true;
            outputTextBox.Clear();
        }

    }
}
