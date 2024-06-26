---
external help file: Logic.Monitor.SE-help.xml
Module Name: Logic.Monitor.SE
online version:
schema: 2.0.0
---

# Import-LMNetscanTemplate

## SYNOPSIS
Import latest enhanced netscans as templates.

## SYNTAX

```
Import-LMNetscanTemplate [-NetscanType] <Object> [-NetscanCollectorId] <Object> [[-NetscanGroupName] <Object>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Import latest enhanced netscans as templates.

## EXAMPLES

### EXAMPLE 1
```
Import-LMNetscanTemplate -NetscanType vSphere -NetscanCollectorId 8 -NetscanGroupName "VMware Template"
```

## PARAMETERS

### -NetscanType
{{ Fill NetscanType Description }}

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NetscanCollectorId
{{ Fill NetscanCollectorId Description }}

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NetscanGroupName
{{ Fill NetscanGroupName Description }}

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: @default
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

### None. Does not accept pipeline input.
## OUTPUTS

## NOTES
Groovy code will be pulled from the LM support site by default to ensure latest version is always used.

## RELATED LINKS

[Module repo: https://github.com/stevevillardi/Logic.Monitor.SE]()

[PSGallery: https://www.powershellgallery.com/packages/Logic.Monitor.SE]()

