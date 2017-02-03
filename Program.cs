using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Transactions;
using System.Net;
using System.Threading.Tasks;
using System.Data.SqlClient;
using System.Net.Mail;
using Microsoft.Office.Interop.Excel;
using System.Configuration;


namespace ISFileImport
{
    class Program
    {
        private static object locker = new object();

        static void Main(string[] args)
        {
            bool silent = (args != null && args.Length != 0 && args[0].ToLower() == "silent");

            List<string> _errors = new List<string>();

            string connectionString = ConfigurationManager.ConnectionStrings["ISAdminAzure"].ConnectionString;

            // InitiateLogger
            string logFilePath = ConfigurationManager.AppSettings["logFilePath"];
            string logFilePrefix = ConfigurationManager.AppSettings["logFileBaseName"];
            string logFileTable = ConfigurationManager.AppSettings["LogTableName"];

            Logger logger = new Logger(logFilePath, logFilePrefix, true, connectionString, logFileTable);

            logger.WriteLogEntry("Begin ISFileImport");
            if (!silent)
                Console.WriteLine("Begin ISFileImport");

            FileImportList fiList = FileImport.GetFileImportLIst(false);
            object lockerObj = new object();

            Parallel.ForEach(fiList,
                            //new ParallelOptions { MaxDegreeOfParallelism = 1 },
                            () => { return new List<string>(); },
                            (fi, loop, sub_errors) => UploadFile(fi, loop, sub_errors, connectionString, silent, logger),
                            (sub_errors) => { lock(lockerObj) _errors.AddRange(sub_errors);}
                            );

            string body = "";
            string subject = "ISFileImport " + DateTime.Now.ToString("yyyy MM dd");

            if (_errors.Count > 0)
            {
                body += "Import finished with errors: " + Environment.NewLine + Environment.NewLine;
                logger.WriteLogEntry("Import finished with errors: ");
                if (!silent)
                    Console.WriteLine("Import finished with errors: ");

                foreach (string item in _errors)
                {
                    body += item + Environment.NewLine;
                    logger.WriteLogEntry(item);
                    if (!silent)
                        Console.WriteLine(item);
                }
            }
            else
            {
                body += "Import finished";
                logger.WriteLogEntry("Import finished");
                if (!silent)
                    Console.WriteLine("Import finished");
            }

            try
            {
                SendNotificationEmail(subject, body);
            }
            catch (Exception e)
            {
                logger.WriteLogEntry("Filed to send notification mail: " + e.Message);
            }
        }

        // Load source file from FTP
        private static bool FTPFile(FileImport fi)
        {
            bool success = true;
            try
            {

                string ftpURI = ConfigurationManager.AppSettings["ftpIP"];
                string ftpUser = ConfigurationManager.AppSettings["ftpUser"];
                string ftpPwd = ConfigurationManager.AppSettings["ftpPwd"];

                string fullUri = fi.FtpPath + fi.FileName;
                int bytesRead = 0;
                byte[] buffer = new byte[2048];

                FileStream fileStream = new FileStream(fi.FilePath + fi.FileName, FileMode.Create);


                FtpWebRequest request = (FtpWebRequest)WebRequest.Create(ftpURI + fullUri);

                request.Method = WebRequestMethods.Ftp.DownloadFile;

                request.Credentials = new NetworkCredential(ftpUser, ftpPwd);

                FtpWebResponse response = (FtpWebResponse)request.GetResponse();

                Stream responseStream = response.GetResponseStream();

                //StreamReader reader = new StreamReader(responseStream);

                while (0 < (bytesRead = (responseStream.Read(buffer, 0, buffer.Length))))
                {
                    fileStream.Write(buffer, 0, bytesRead);
                }

                fileStream.Close();
            }
            catch (Exception e)
            {
                // Log the error
                success = false;
            }
            return success;
        }

        /// <summary>
        /// Converts Excel files to csv for processing
        /// </summary>
        /// <param name="fi">FileImport object which hold data for table being inserted into</param>
        private static bool ConvertExcel(FileImport fi)
        {
            Application excel = new Application();
            bool success = true;

            try
            {
                Workbook wb = excel.Workbooks.Open(fi.FilePath + fi.FileName);
                excel.DisplayAlerts = false;
                //Worksheet sheet = wb.Worksheets["ShopsPerMonth"];

                //Range FormatRange = sheet.UsedRange.Columns["Z:AL"];
                //FormatRange.NumberFormat = "0";

                //Range FormatRange2 = sheet.UsedRange.Columns["M:N"];
                //FormatRange2.NumberFormat = "0.00";

                wb.SaveAs(fi.FilePath + Path.GetFileNameWithoutExtension(fi.FilePath + fi.FileName), XlFileFormat.xlCSV, Type.Missing, Type.Missing, Type.Missing, false, XlSaveAsAccessMode.xlNoChange, XlSaveConflictResolution.xlLocalSessionChanges, Type.Missing, Type.Missing);
                fi.FileName = Path.GetFileNameWithoutExtension(fi.FilePath + fi.FileName) + ".csv";
            }
            catch (Exception e)
            {
                //lock(locker) logger.WriteLogEntry("Error converting Excel File: " + e.Message);
                success = false;
            }
            finally
            {
                if (excel != null)
                    excel.Quit();
            }

            return success;
        }

        /// <summary>
        /// Upload a single file's to SQL Server as specified in connectionString. Meant to be run in parallel in Parallel.Foreach
        /// </summary>
        /// <param name="fi">FileImport object with data on the table being imported to.</param>
        /// <param name="loop">Varaible to track state of Parallel ForEach loop</param>
        /// <param name="_errors">List of error strings to be printed at end of program</param>
        /// <param name="connectionString">Connection string for SQL connections</param>
        /// <param name="silent">Determines whether output is shown to console</param>
        /// <param name="logger">Logger object to print daily log file</param>
        /// <returns>String with any errors which occur during upload</returns>
        private static List<string> UploadFile(FileImport fi, ParallelLoopState loop, List<string> _errors, string connectionString, bool silent, Logger logger)
        {
            //int TestCount = 0;
            //int testSkip = 0;
            int numberOfRows = 0;
            SqlCommand cmd = new SqlCommand();
            System.Data.DataTable dtImports = new System.Data.DataTable();

            try
            {
                lock (locker) logger.WriteLogEntry("Beginning file: " + fi.FileName);
                if (!silent)
                    Console.WriteLine("Beginning file: " + fi.FileName);

                if (fi.IsFTP)
                {
                    if (!FTPFile(fi))
                    {
                        _errors.Add("Unable to FTP File " + fi.FileName);
                        lock (locker) logger.WriteLogEntry("Unable to FTP File " + fi.FileName);
                        if (!silent)
                            Console.WriteLine("Unable to FTP File " + fi.FileName);

                    }
                }

                if (fi.FileType.ToLower() == "xlsx" || fi.FileType.ToLower() == "xls")
                {
                    if (!ConvertExcel(fi))
                        _errors.Add("Error converting Excel File: " + fi.FileName);
                }

                using (TransactionScope ts = new TransactionScope(TransactionScopeOption.RequiresNew, new TimeSpan(0, 5, 0)))
                using (SqlConnection dbConn = new SqlConnection(connectionString))
                {
                    //if (TestCount < testSkip)
                    //{
                    //    TestCount++;
                    //    continue;
                    //}

                    // Run pre-Import sql, if any

                    cmd.Connection = dbConn;
                    cmd.CommandTimeout = 300;

                    dbConn.Open();
                    if (!string.IsNullOrEmpty(fi.SqlBeforeImport))
                    {
                        lock (locker) logger.WriteLogEntry("Running pre import SQL for : " + fi.FileName);
                        if (!silent)
                            Console.WriteLine("Running pre import SQL for : " + fi.FileName);

                        cmd.CommandText = fi.SqlBeforeImport;
                        cmd.ExecuteNonQuery();
                    }
                    dbConn.Close();

                    // Populate dtImports with import table fields
                    dbConn.Open();
                    using (TransactionScope ts2 = new TransactionScope(TransactionScopeOption.Suppress))
                    {
                        cmd.CommandText = "SELECT TOP 1 * FROM " + fi.DbTable;
                    }
                    dbConn.Close();

                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                        da.Fill(dtImports);

                    // Copy file to SQL Server in batches
                    lock (locker) logger.WriteLogEntry("Loading File: " + fi.FileName);
                    if (!silent)
                        Console.WriteLine("Loading File: " + fi.FileName);

                    dbConn.Open();
                    using (SqlBulkCopy bc = new SqlBulkCopy(dbConn, SqlBulkCopyOptions.TableLock, null))
                    using (FileImportDataReader fidr = new FileImportDataReader(fi, dtImports))
                    {
                        try
                        {
                            bc.BulkCopyTimeout = 0;
                            bc.BatchSize = 2000;
                            bc.DestinationTableName = fi.DbTable;
                            bc.NotifyAfter = 0;
                            bc.WriteToServer(fidr);
                            numberOfRows = fidr.CurrentIndex;
                        }
                        catch (Exception e)
                        {
                            numberOfRows = fidr.CurrentIndex;
                            throw e;
                        }
                    }
                    dbConn.Close();

                    lock (locker) logger.WriteLogEntry(fi.Name + ": " + numberOfRows.ToString() + " rows imported");
                    if (!silent)
                        Console.WriteLine(fi.Name + ": " + numberOfRows.ToString() + " rows imported");

                    // Run post-import SQL
                    dbConn.Open();
                    if (!string.IsNullOrEmpty(fi.SqlAfterImport))
                    {
                        lock (locker) logger.WriteLogEntry("Running after import SQL for : " + fi.FileName);
                        if (!silent)
                            Console.WriteLine("Running after import SQL for : " + fi.FileName);

                        cmd.CommandText = fi.SqlAfterImport;
                        cmd.ExecuteNonQuery();
                    }
                    dbConn.Close();

                    ts.Complete();
                }
            }
            catch (Exception e)
            {
                _errors.Add(fi.FileName + ": line: " + numberOfRows + " Source: " + e.Source + ": " + e.Message);
            }

            return _errors;
        }

        // Send completion message via email
        private static void SendNotificationEmail(string subject, string body)
        {
            string recipients = ConfigurationManager.AppSettings["NotificationRecipients"];

            List<string> recipientList = recipients.Split(';').ToList<string>();

            MailMessage message = new MailMessage();

            foreach (string item in recipientList)
            {
                message.To.Add(new MailAddress(item));
            }

            message.Subject = subject;
            message.Body = body;

            using (SmtpClient client = new SmtpClient())
            {
                client.Send(message);
            }

        }


    }
}
