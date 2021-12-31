
<!--
*** Thanks for checking out the README. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again!
-->

<!-- ABOUT THE Code -->
## About The Code

We had a need access the AWS EC2 servers thourgh port 22 from Azure Virtual Machine. We got the required IP address rages to be whiltelisted
in Azure VM but the IP address are not static and we do not have option to whitelist a URL in Azure NSG.

Hence, I have worked this power shell script to accomplish this from Azure Automation account as runbook.
And we can schedule the runbook to trigger this script everyday once.

We have to manually whitelist the IP addreess for the first time.

Here's how it works:
* The code connect to Azure with the application ID to authentication.
* It fetches the AWS EC2 service IP ranges into a csv file under temp folder of the automation account.
* We have used 230 and 231 priority under the given Azure NSG.
* Code will check which priority is being used and which is free.
* Also, we have one csv file under the given Azure Storage account, which will has the previous IP ranges.
* Code will compare the existing IP ranges and the new IP ranges. If there is no difference. it will not do anything.
* If any difference found, code will create new rule with the available priority (between 230 and 231)
* will upload the new Ip ranges csv file under storage account and delete the old csv file.

I had to use the new rule creation method, as the updating existing nsg rule PowerShell command is not working as of now.




<p align="right">(<a href="#top">back to top</a>)</p>
