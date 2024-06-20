namespace GUI2
{
    public class ConfigModels
    {
        public HP HP { get; set; }
        public Lenovo Lenovo { get; set; }
        public Dell Dell { get; set; }
    }

    public class HP
    {
        public string LocalPath { get; set; }
        public string NetworkPath { get; set; }
        public string PowerShellExe { get; set; }
        public string DriverScriptName { get; set; }
    }

    public class Lenovo
    {
        public string DriverScriptName { get; set; }
        public string DownloadPath { get; set; }
        public string NetworkPath { get; set; }
        public string CatalogPath { get; set; }
        public int DaysToRefresh { get; set; }
    }

    public class Dell
    {
        public string DriverScriptName { get; set; }
        public string DownloadPath { get; set; }
        public string NetworkPath { get; set; }
    }
}
