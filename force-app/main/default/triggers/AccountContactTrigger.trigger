trigger AccountContactTrigger on AccountContact__c (before insert, after update, before update, after delete) {

  if(Trigger.isBefore && Trigger.isInsert) {
    AccountContactTriggerHandler.haveDuplicateAccountContacts(Trigger.New);
    AccountContactTriggerHandler.checkWorkplacesBeforeInsert(Trigger.New);
  }

  if(Trigger.isAfter && Trigger.isUpdate) {
    AccountContactTriggerHandler.haveDuplicateAccountContacts(Trigger.New);
    AccountContactTriggerHandler.updateIsPrimary(Trigger.oldMap, Trigger.newMap);
  }

  if(Trigger.isBefore && Trigger.isUpdate) {
    AccountContactTriggerHandler.haveDuplicateAccountContacts(Trigger.New);
    AccountContactTriggerHandler.updateIsPrimary(Trigger.oldMap, Trigger.newMap);
  }

  if(Trigger.isAfter && Trigger.isDelete) {
    AccountContactTriggerHandler.handlePrimaryAfterDelete(Trigger.Old);
  }
}
