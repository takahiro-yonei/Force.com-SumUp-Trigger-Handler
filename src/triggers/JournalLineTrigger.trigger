trigger JournalLineTrigger on JournalLine__c (after delete, after insert, after update) {
	TrgHandler_SumUp sumupHandler = new TrgHandler_SumUp('JournalLine__c', Trigger.isExecuting, Trigger.size);
	
	if(Trigger.isAfter){
		List<SObject> paramLines = (Trigger.isInsert || Trigger.isUpdate) ? Trigger.new : Trigger.old;
		sumupHandler.OnAfterTrigger_Sumup(paramLines);
	}
	
}