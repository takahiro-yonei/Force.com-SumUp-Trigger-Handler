@isTest
private class UnitTest_SumupTrigger {

	static Journal__c setupJournal(){
		Account wkAcc = new Account(Name = 'Test', AccountNumber = '001');
		insert wkAcc;
		
		Journal__c newJ = new Journal__c(
			Account__c = wkAcc.Id,
			JournalDate__c = Date.today()
		);
		insert newJ;
		
		Product2 pd1 = new Product2(Name = 'TestProduct01', ProductCode = 'Code001', IsActive = true);
		insert pd1;
		
		Product2 pd2 = new Product2(Name = 'TestProduct02', ProductCode = 'Code002', IsActive = true);
		insert pd2;
		
		Product2 pd3 = new Product2(Name = 'TestProduct03', ProductCode = 'Code003', IsActive = true);
		insert pd3;
		
		List<JournalLine__c> insLines = new List<JournalLine__c>();
		for(Integer i=0;i<15;i++){
			JournalLine__c wkLine = new JournalLine__c(
					Journal__c = newJ.Id,
					Qty__c = i+1,
					UnitPrice__c = (i+1) * 50,
					UnitCost__c = (i+1) * 30
				);
			if(math.mod(i,4) == 0){
				// i = 0, 4, 8, 12
				// Amount = 50, 1250, 4050, 8450 : Sum = 13800
				wkLine.Product2__c = pd1.Id;
			} else if(math.mod(i,4) == 1){
				// i = 1, 5, 9, 13
				// Amount = 200, 1800, 5000, 9800 : Sum = 16800
				wkLine.Product2__c = pd2.Id;
			} else if(math.mod(i,4) == 2){
				// i = 2, 6, 10, 14
				// Amount = 450, 2450, 6050, 11250 : Sum = 20200
				wkLine.Product2__c = pd3.Id;
			}
			insLines.add(wkLine);
		}
		insert insLines;
		
		newJ = [Select Name, JournalDate__c, Account__c, Amount__c, AmountSum__c,
				(Select Name,LineName__c,Qty__c,UnitPrice__c,UnitCost__c,Amount__c From JournalLines__r Order By Name)
			From Journal__c Where Id = :newJ.Id];
		return newJ;
	}
	
    static testMethod void Test_TriggerAction_Create(){
        Journal__c testJournal = setupJournal();
        
        Test.startTest();
        
        System.assertEquals(testJournal.JournalLines__r.size(), 15);
        System.assertEquals(testJournal.Amount__c, testJournal.AmountSum__c);
        
        // Add New Line
        JournalLine__c newLine = new JournalLine__c(
				Journal__c = testJournal.Id,
				Qty__c = 40,
				UnitPrice__c = 30,
				UnitCost__c = 20
        	);
        insert newLine;
        
        // Check Journal
        testJournal = [Select Name, JournalDate__c, Account__c, Amount__c, AmountSum__c,
				(Select Name,LineName__c,Qty__c,UnitPrice__c,UnitCost__c,Amount__c From JournalLines__r Order By Name)
			From Journal__c Where Id = :testJournal.Id];
        System.assertEquals(testJournal.Amount__c, testJournal.AmountSum__c);
        
        // Check Product2
        Product2 pd1 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct01' and ProductCode = 'Code001'];
        System.assertEquals(pd1.AmountSum__c, 13800);
        Product2 pd2 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct02' and ProductCode = 'Code002'];
        System.assertEquals(pd2.AmountSum__c, 16800);
        Product2 pd3 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct03' and ProductCode = 'Code003'];
        System.assertEquals(pd3.AmountSum__c, 20200);
        
        
        Test.stopTest();
    }
    
    static testMethod void Test_TriggerAction_Update(){
    	Journal__c testJournal = setupJournal();
        
        Product2 pd4 = new Product2(Name = 'TestProduct04', ProductCode = 'Code004', IsActive = true);
        insert pd4;
        
        JournalLine__c wkLine = testJournal.JournalLines__r[3];
        wkLine.UnitPrice__c = 400;
        wkLine.Qty__c = 50;
        wkLine.Product2__c = pd4.Id;
        update wkLine;
        
        Test.startTest();
        
        // Check Journal
        testJournal = [Select Name, JournalDate__c, Account__c, Amount__c, AmountSum__c,
				(Select Name,LineName__c,Qty__c,UnitPrice__c,UnitCost__c,Amount__c From JournalLines__r Order By Name)
			From Journal__c Where Id = :testJournal.Id];
        System.assertEquals(testJournal.Amount__c, testJournal.AmountSum__c);
        
        // Check Product
        pd4 = [Select Id,AmountSum__c From Product2 Where Id = :pd4.Id];
        System.assertEquals(pd4.AmountSum__c, 20000);
        
        wkLine.UnitPrice__c = 500;
        update wkLine;
        
        pd4 = [Select Id,AmountSum__c From Product2 Where Id = :pd4.Id];
        System.assertEquals(pd4.AmountSum__c, 25000);
        
        
        Test.stopTest();
    }
    
    static testMethod void Test_TriggerAction_Delete(){
    	Journal__c testJournal = setupJournal();
        
        // Delete LastLine
        JournalLine__c wkLine = testJournal.JournalLines__r[14];
        delete wkLine;
        
        Test.startTest();
        
        testJournal = [Select Name, JournalDate__c, Account__c, Amount__c, AmountSum__c,
				(Select Name,LineName__c,Qty__c,UnitPrice__c,UnitCost__c,Amount__c From JournalLines__r Order By Name)
			From Journal__c Where Id = :testJournal.Id];
        System.assertEquals(testJournal.Amount__c, testJournal.AmountSum__c);
        
        // Check Product2
        Product2 pd1 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct01' and ProductCode = 'Code001'];
        System.assertEquals(pd1.AmountSum__c, 13800);
        Product2 pd2 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct02' and ProductCode = 'Code002'];
        System.assertEquals(pd2.AmountSum__c, 16800);
        Product2 pd3 = [Select Id,AmountSum__c From Product2 Where Name = 'TestProduct03' and ProductCode = 'Code003'];
        System.assertEquals(pd3.AmountSum__c, 8950);
        
        
        // Delete All
        List<JournalLine__c> lines = testJournal.JournalLines__r;
        delete lines;
        
        testJournal = [Select Name, JournalDate__c, Account__c, Amount__c, AmountSum__c,
				(Select Name,LineName__c,Qty__c,UnitPrice__c,UnitCost__c,Amount__c From JournalLines__r Order By Name)
			From Journal__c Where Id = :testJournal.Id];
        System.assertEquals(testJournal.Amount__c, testJournal.AmountSum__c);
        System.assertEquals(0, testJournal.AmountSum__c);
        
        // Check Product2
        pd1 = [Select Id,AmountSum__c From Product2 Where Id = :pd1.Id];
        System.assertEquals(pd1.AmountSum__c, 0);
        pd2 = [Select Id,AmountSum__c From Product2 Where Id = :pd2.Id];
        System.assertEquals(pd2.AmountSum__c, 0);
        pd3 = [Select Id,AmountSum__c From Product2 Where Id = :pd3.Id];
        System.assertEquals(pd3.AmountSum__c, 0);
        
        Test.stopTest();
    }
}