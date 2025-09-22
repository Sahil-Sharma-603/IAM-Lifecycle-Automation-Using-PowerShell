#Hash function 

@{
  ReportDir            = 'reports' # where CSV/HTML reports go
  DormantDaysThreshold = 30        # “inactive” if no login for >= 30 days
  PasswordLength       = 12        # temp password length
} | Out-File -Encoding utf8 config.psd1
