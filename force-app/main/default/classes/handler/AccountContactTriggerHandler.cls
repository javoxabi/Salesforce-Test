public with sharing class AccountContactTriggerHandler {

    public static void checkWorkplacesBeforeInsert(List<AccountContact__c> newAccountContacts) {

        Map<Id, AccountContact__c> contactAccountContactMap = new Map<Id, AccountContact__c>();
        for(AccountContact__c accCon : newAccountContacts) {
            contactAccountContactMap.put(accCon.Contact__c, accCon);
        }

        List<AccountContact__c> existingAccountContacts = [SELECT Id, Contact__c, isPrimary__c FROM AccountContact__c WHERE Contact__c IN :contactAccountContactMap.keySet()  WITH SECURITY_ENFORCED ORDER BY isPrimary__c DESC];
        Map<Id, AccountContact__c> existingAccountContactMap = new Map<Id, AccountContact__c>();

        for(AccountContact__c existAccCon : existingAccountContacts) {
            existingAccountContactMap.put(existAccCon.Contact__c, existAccCon);
        }

        Set<Id> processedContacts = new Set<Id>();

        for(AccountContact__c accCon : newAccountContacts) {
            if(!existingAccountContactMap.containsKey(accCon.Contact__c) && (!processedContacts.contains(accCon.Contact__c))) {
                accCon.isPrimary__c = true;
                processedContacts.add(accCon.Contact__c);
            } else {
                accCon.isPrimary__c = false;
            }
        }
    }

    public static void updateIsPrimary(Map<Id, AccountContact__c> oldMap, Map<Id, AccountContact__c> newMap) {
        List<Id> contactIds = new List<Id>();

        for (AccountContact__c acc : newMap.values()) {
            AccountContact__c oldAcc = oldMap.get(acc.Id);
            if (oldAcc.IsPrimary__c != acc.IsPrimary__c) {
                contactIds.add(acc.Contact__c);
            }
        }

        if (!contactIds.isEmpty()) {
            Map<Id, List<AccountContact__c>> contactToAccountContacts = new Map<Id, List<AccountContact__c>>();

            for (AccountContact__c ac : [
                SELECT Id, Contact__c, CreatedDate, IsPrimary__c 
                FROM AccountContact__c 
                WHERE Contact__c IN :contactIds WITH SECURITY_ENFORCED
                ORDER BY Contact__c, CreatedDate DESC
            ]) {
                if (!contactToAccountContacts.containsKey(ac.Contact__c)) {
                    contactToAccountContacts.put(ac.Contact__c, new List<AccountContact__c>());
                }
                contactToAccountContacts.get(ac.Contact__c).add(ac);
            }

            if (Trigger.isAfter) {
                updatePrimaryWorkplaces(newMap, oldMap, contactToAccountContacts);
            }
            if (Trigger.isBefore) {
                preventUpdateIfOneAccountContact(newMap, oldMap, contactToAccountContacts);
            }
        }
    }

    private static void updatePrimaryWorkplaces(Map<Id, AccountContact__c> newMap, Map<Id, AccountContact__c> oldMap, Map<Id, List<AccountContact__c>> contactToAccountContacts) {

        List<AccountContact__c> accountContactsForUpdate = new List<AccountContact__c>();

        for (AccountContact__c acc : newMap.values()) {
            AccountContact__c oldAcc = oldMap.get(acc.Id);
            if (oldAcc.IsPrimary__c != acc.IsPrimary__c && contactToAccountContacts.containsKey(acc.Contact__c)) {
                List<AccountContact__c> accountContacts = contactToAccountContacts.get(acc.Contact__c);
    
                if (acc.IsPrimary__c == true && accountContacts.size() > 1) {
                    for (AccountContact__c ac : accountContacts) {
                        if (ac.Id != acc.Id) {
                            ac.IsPrimary__c = false;
                            accountContactsForUpdate.add(ac);
                            break;
                        }
                    }
                } else if (acc.IsPrimary__c == false && accountContacts.size() > 1) {
                    for (AccountContact__c ac : accountContacts) {
                        if (ac.Id != acc.Id) {
                            ac.IsPrimary__c = true;
                            accountContactsForUpdate.add(ac);
                            break;
                        }
                    }
                }
            }
        }

        update accountContactsForUpdate;
    }

    private static void preventUpdateIfOneAccountContact(Map<Id, AccountContact__c> newMap, Map<Id, AccountContact__c> oldMap, Map<Id, List<AccountContact__c>> contactToAccountContacts) {

        for (AccountContact__c acc : newMap.values()) {
            AccountContact__c oldAcc = oldMap.get(acc.Id);
            if (oldAcc.IsPrimary__c && !acc.IsPrimary__c && contactToAccountContacts.containsKey(acc.Contact__c)) {
                List<AccountContact__c> accountContacts = contactToAccountContacts.get(acc.Contact__c);

                if (accountContacts.size() == 1) {
                    acc.IsPrimary__c = true;
                    acc.addError('Cannot update isPrimary to false for ' + acc.Id + ' - There is only one AccountContact');
                }
            }
        }
    }


    public static void handlePrimaryAfterDelete(List<AccountContact__c> deletedAccs) {
        Set<Id> contactIds = new Set<Id>();
        for (AccountContact__c acc : deletedAccs) {
            if(acc.isPrimary__c) {
                contactIds.add(acc.Contact__c);
            }
        }

        if (contactIds.isEmpty()) {
            return;
        }
    
        Map<Id, AccountContact__c> contactToLatestAcc = new Map<Id, AccountContact__c>();
        List<AccountContact__c> otherAccountContacts = new List<AccountContact__c>();
        for (AccountContact__c ac : [
                SELECT Id, Contact__c, CreatedDate, IsPrimary__c 
                FROM AccountContact__c 
                WHERE Contact__c IN :contactIds 
                AND Id NOT IN :deletedAccs WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC]) {
            if (!contactToLatestAcc.containsKey(ac.Contact__c)) {
                contactToLatestAcc.put(ac.Contact__c, ac);
            } else {
                ac.IsPrimary__c = false;
                otherAccountContacts.add(ac);
            }
        }
    
        List<AccountContact__c> accsToUpdate = new List<AccountContact__c>();
        for (AccountContact__c acc : contactToLatestAcc.values()) {
            acc.IsPrimary__c = true;
            accsToUpdate.add(acc);
        }

        accsToUpdate.addAll(otherAccountContacts);
    
        update accsToUpdate;
    }
    

    


    public static void haveDuplicateAccountContacts(List<AccountContact__c> newAccountContacts) {
        Set<Id> contactIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
    
        for (AccountContact__c ac : newAccountContacts) {
            contactIds.add(ac.Contact__c);
            accountIds.add(ac.Account__c);
        }
    
        List<AccountContact__c> existingRecords = [SELECT Id, Contact__c, Account__c FROM AccountContact__c
                                                WHERE Contact__c IN :contactIds AND Account__c IN :accountIds WITH SECURITY_ENFORCED];
    
        Map<String, AccountContact__c> existingMap = new Map<String, AccountContact__c>();
        for (AccountContact__c ac : existingRecords) {
            String key = ac.Contact__c + '-' + ac.Account__c;
            existingMap.put(key, ac);
        }
        
        Map<String, AccountContact__c> newAccountContactsMap = new Map<String, AccountContact__c>();
    
        for (AccountContact__c ac : newAccountContacts) {
            String key = ac.Contact__c + '-' + ac.Account__c;
            if (existingMap.containsKey(key) && Trigger.isInsert) {
                ac.addError('Duplicate AccountContact found in existing data');
            }
            
            if (newAccountContactsMap.containsKey(key)) {
                ac.addError('Duplicate AccountContact found in the new records');
            } else {
                newAccountContactsMap.put(key, ac);
            }
        }
    }
    

}