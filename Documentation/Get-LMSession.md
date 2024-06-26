---
external help file: Logic.Monitor.SE-help.xml
Module Name: Logic.Monitor.SE
online version:
schema: 2.0.0
---

# Get-LMSession

## SYNOPSIS
This function retrieves a session from Logic Monitor.

## SYNTAX

```
Get-LMSession [-AccountName] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Get-LMSession function uses the account name provided to retrieve a session from Logic Monitor. 
It uses a secret API key stored in a vault to authenticate the request.

## EXAMPLES

### EXAMPLE 1
```
Get-LMSession -AccountName "Account1"
```

This command retrieves the session details for the account named "Account1".

## PARAMETERS

### -AccountName
The name of the account for which the session details are to be retrieved.
This is a mandatory parameter.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String. You can pipe a string that contains the account name to Get-LMSession.
## OUTPUTS

### The function returns the response from the Invoke-RestMethod cmdlet, which contains the session details.
## NOTES
The function throws an error if it fails to retrieve the session details.

## RELATED LINKS
