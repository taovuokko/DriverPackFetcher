using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;

namespace GUI2
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
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
            }
        }

        private async void SearchButton_Click(object sender, RoutedEventArgs e)
        {
            string driverScriptName = null;
            string firmwareScriptName = null;
            string modelName = null;
            string csvPath = null;
            bool includeFirmware = false;

            // Access UI elements using Dispatcher.Invoke
            Dispatcher.Invoke(() =>
            {
                driverScriptName = radioButtonLenovo.IsChecked == true ? "Lenovo-Drivers.ps1" : "Dell-Drivers.ps1";
                firmwareScriptName = "Download-Lenovo-Firmware.ps1";
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

            string driverDownloadPath = Path.Combine(Path.GetTempPath(), "LenovoDrivers");
            string firmwareDownloadPath = Path.Combine(Path.GetTempPath(), "LenovoFirmware");
            string networkPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "LocalLenovo");

            // Run driver script
            await Task.Run(() => RunPowerShellScript(driverScriptName, modelName, driverDownloadPath, networkPath, csvPath, false));

            // Run firmware script if IncludeFirmware is checked
            if (includeFirmware)
            {
                await Task.Run(() => RunPowerShellScript(firmwareScriptName, modelName, firmwareDownloadPath, networkPath, csvPath, true));
            }
        }

        private void HideInputElements()
        {
            radioButtonLenovo.Visibility = Visibility.Collapsed;
            radioButtonDell.Visibility = Visibility.Collapsed;
            radioButtonSingleModel.Visibility = Visibility.Collapsed;
            radioButtonCsvModel.Visibility = Visibility.Collapsed;
            modelNameTextBox.Visibility = Visibility.Collapsed;
            checkBoxFirmware.Visibility = Visibility.Collapsed;
        }

        private void RunPowerShellScript(string scriptName, string modelName, string downloadPath, string networkPath, string csvPath, bool includeFirmware)
        {
            string tempScriptPath = Path.Combine(Path.GetTempPath(), scriptName);

            try
            {
                string scriptContent = GetEmbeddedResource($"GUI2.Resources.{scriptName}");

                if (string.IsNullOrEmpty(scriptContent))
                {
                    Dispatcher.Invoke(() =>
                    {
                        MessageBox.Show("Script content is empty or not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    });
                    return;
                }

                File.WriteAllText(tempScriptPath, scriptContent, new UTF8Encoding(true)); // Ensure BOM
                AppendOutput($"Script written to {tempScriptPath}");

                string arguments = $"-NoProfile -ExecutionPolicy Bypass -File \"{tempScriptPath}\" -ModelName \"{modelName}\" -DownloadPath \"{downloadPath}\" -NetworkPath \"{networkPath}\"";
                if (!string.IsNullOrEmpty(csvPath))
                {
                    arguments += $" -CsvPath \"{csvPath}\"";
                }
                if (includeFirmware)
                {
                    arguments += " -IncludeFirmware";
                }

                AppendOutput($"Running script with arguments: {arguments}");

                ProcessStartInfo startInfo = new ProcessStartInfo()
                {
                    FileName = "powershell.exe",
                    Arguments = arguments,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (Process process = new Process() { StartInfo = startInfo })
                {
                    process.OutputDataReceived += (s, e) => AppendOutput(e.Data);
                    process.ErrorDataReceived += (s, e) => AppendOutput(e.Data);

                    process.Start();
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();
                    process.WaitForExit();

                    AppendOutput($"Process exited with code: {process.ExitCode}");
                    if (process.ExitCode != 0)
                    {
                        AppendOutput($"Error occurred while running PowerShell script. Exit code: {process.ExitCode}");
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
                            using (StreamReader reader = new StreamReader(stream, Encoding.UTF8))
                            {
                                return reader.ReadToEnd();
                            }
                        }
                    }
                }
            }
            return null;
        }
    }
}
