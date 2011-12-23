SumUp Trigger Utility
========================

This is a Trigger Utility for Force.com.

This utility calculate sum of number field in a Child Custom Object.

And this utility update sum value to a Parent Custom Object number field whose name is same to the Child Custom Object's number field and ends with 'Sum'.


Usage
========================

Parent Object(Name: Journal__c):

    <CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
        ....
        <fields>
            <fullName>AmountSum__c</fullName>
            <defaultValue>0</defaultValue>
            <externalId>false</externalId>
            <label>金額（税抜）</label>
            <precision>12</precision>
            <required>false</required>
            <scale>2</scale>
            <trackHistory>false</trackHistory>
            <type>Currency</type>
        </fields>
    </CustomObject>

Child Object(Name: JournalLine__c)

    <CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
        ....
        <fields>
            <fullName>Amount__c</fullName>
            <externalId>false</externalId>
            <formula>UnitPrice__c  *  Qty__c</formula>
            <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
            <label>明細金額（税抜）</label>
            <precision>18</precision>
            <required>false</required>
            <scale>2</scale>
            <trackHistory>false</trackHistory>
            <type>Currency</type>
        </fields>
    </CustomObject>

Trigger: ("TrgHandler_SumUp" is a SumUp Trigger Utility)

	trigger JournalLineTrigger on JournalLine__c (after delete, after insert, after update) {
		TrgHandler_SumUp sumupHandler = new TrgHandler_SumUp('JournalLine__c', Trigger.isExecuting, Trigger.size);
		if(Trigger.isAfter){
			List<SObject> paramLines = (Trigger.isInsert || Trigger.isUpdate) ? Trigger.new : Trigger.old;
			sumupHandler.OnAfterTrigger_Sumup(paramLines);
		}
	
	}


