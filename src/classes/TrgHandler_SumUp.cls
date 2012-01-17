public without sharing class TrgHandler_SumUp {
	private Boolean IsExecuting = false;
	private Integer BatchSize = 0;
	private Schema.SObjectType objType;
	private Map<String, Schema.SObjectField> objSchemaMap;
	

	public TrgHandler_SumUp(String cObjName, boolean param_IsExecuting, Integer param_Size){
		this.IsExecuting = param_IsExecuting;
		this.BatchSize = param_Size;
		this.objType = Schema.getGlobalDescribe().get(cObjName);
		this.objSchemaMap = objType.getDescribe().Fields.getMap();
	}
	
	/**
	* トリガで更新(or削除)のあった子オブジェクトレコードを受け取って、集計対象項目を取得＆集計し、親オジェクト側に集計結果を反映する
	* @param paramLines : 子オブジェクトレコードのリスト
	**/
	public void OnAfterTrigger_Sumup(SObject[] cLines){
		Savepoint sp;
		try{
			sp = Database.setSavepoint();
			
			List<SObject> updPList = new List<SObject>();
			for(Schema.SObjectField wkFld : objSchemaMap.values()){
				Schema.DescribeFieldResult descFld = wkFld.getDescribe();
				
				for(Schema.sObjectType wkParentObjType : descFld.getReferenceTo()){
					ParentObj pObj = new ParentObj(objType, objSchemaMap, descFld.getName(), wkParentObjType.getDescribe().getName(), cLines);
					updPList.addAll(pObj.getUpdateObjs());
				}
			}
			update updPlist;
			
		}catch(Exception ex){
			Database.rollback(sp);
			System.debug('*** Error OnAfterTrigger_Sumup : ' + ex.getMessage());
		}
	}
	
	
	
	/**
	* Inner Class
	*  親オブジェクトごとに、親オブジェクト名、親オブジェクトを参照する項目名、親オブジェクトId等を格納する
	*  また、親オブジェクトの集計先項目のUpdate用Listを作成する
	**/
	private class ParentObj{
		public final String POSTFIX_SUM = 'Sum';
		
		private String ParentObjName;							// 親オブジェクト名
		private String ParentObjRefName;						// 親オブジェクトを参照する子オブジェクト側の項目名
		private Set<String> ParentIds;							// 親オブジェクトIdのSet
		private Map<String, String> ChildToParentItemMap;		// 集計対象と集計先項目のマップ（key: 子オブジェクトの集計項目 value: 親オブジェクトの集計先項目）
		private Schema.SObjectType objType;
		private Map<String, Schema.SObjectField> objSchemaMap;
		
		
		public ParentObj(Schema.SObjectType cObjType, Map<String, Schema.SObjectField> cObjSchemaMap, String pObjRefName, String pObjName, List<SObject> cLines){
			objType = cObjType;
			objSchemaMap = cObjSchemaMap;
			ParentObjName = pObjName;
			ParentObjRefName = pObjRefName;
			ParentIds = getParentObjIds(cLines);
			ChildToParentItemMap = getChildToParentItemMap();
		}
		
		/**
		* 親オブジェクトのId用Setを作成する
		**/
		private Set<String> getParentObjIds(List<SObject> paramLines){
			Set<String> rtn = new Set<String>();
			for(SObject line : paramLines){
				if(line.get(ParentObjRefName) != null){
					rtn.add(String.valueOf(line.get(ParentObjRefName)));
				}
			}
			return rtn;
		}
		
		/**
		* 親オブジェクト名から、集計項目と集計先項目のマップを作成する
		*  key: 子オブジェクト側の集計対象項目　value: 親オブジェクト側の集計先項目
		**/
		private Map<String, String> getChildToParentItemMap(){
			Map<String, String> rtn = new Map<String, String>();
			Map<String, Schema.SObjectField> pObjSchemaMap = Schema.getGlobalDescribe().get(ParentObjName).getDescribe().Fields.getMap();
			
			for(Schema.SObjectField wkFld : objSchemaMap.values()){
				Schema.DescribeFieldResult descFld = wkFld.getDescribe();
				if(descFld.isCustom() && (descFld.getType() == Schema.DisplayType.Currency || descFld.getType() == Schema.DisplayType.Double || descFld.getType() == Schema.DisplayType.Integer || descFld.getType() == Schema.DisplayType.Percent)){
					// 親側の項目名を生成する
					String wkSumItemName = (descFld.getName().split('__').size() == 2 ? descFld.getName().split('__')[0] : descFld.getName().split('__')[1]) + POSTFIX_SUM + '__c';
					if(pObjSchemaMap.containsKey(wkSumItemName)){
						// 親側に項目が存在して、数値属性の項目だった場合、Mapに追加する
						Schema.DescribeFieldResult pFld = pObjSchemaMap.get(wkSumItemName).getDescribe();
						if(pFld.getType() == Schema.DisplayType.Currency || pFld.getType() == Schema.DisplayType.Double || pFld.getType() == Schema.DisplayType.Integer || pFld.getType() == Schema.DisplayType.Percent){
							rtn.put(descFld.getName(), wkSumItemName);
						}
					}
				}
			}
			return rtn;
		}
		
		/**
		* 子オブジェクト側の集計対象項目を集計して、親オブジェクト側の集計先項目に反映したリストを作成する
		**/
		public List<SObject> getUpdateObjs(){
			List<SObject> rtn = new List<SObject>();
			String query = '';
			if(ChildToParentItemMap.size() > 0 && ParentIds.size() > 0){
				// 子オブジェクト側の集計用のデータを取得する
				query = 'Select ' + ParentObjRefName + ' ';
				for(String wkCol : ChildToParentItemMap.keySet()){ query += ',SUM(' + wkCol + ') ' + wkCol + ' '; }
				query += 'From ' + objType.getDescribe().getName() + ' Where ' + ParentObjRefName + ' IN (' + joinArray(ParentIds, true) + ') ';
				query += 'Group By ' + ParentObjRefName;
				Map<Id, AggregateResult> cDataMap = new Map<Id, AggregateResult>();
				for(AggregateResult ar : (List<AggregateResult>)Database.query(query)){
					cDataMap.put(String.valueOf(ar.get(ParentObjRefName)), ar);
				}
				
				// 親オブジェクトのレコードを取得する
				query = 'Select Id,' + joinArray(ChildToParentItemMap.values(), false) + ' ';
				query += 'From ' + ParentObjName + ' Where Id IN (' + joinArray(ParentIds, true) + ') ';
				Map<Id, SObject> pDataMap = new Map<Id, SObject>();
				for(SObject obj : (List<SObject>)Database.query(query)){
					pDataMap.put(String.valueOf(obj.get('Id')), obj);
				}
				
				// 集計対象項目の集計値を、親オブジェクトの集計先項目にセットする
				for(Id wkPId : pDataMap.keySet()){
					AggregateResult cObj = cDataMap.get(wkPId);
					SObject pObj = pDataMap.get(wkPId);
					
					for(String cCol : ChildToParentItemMap.keySet()){
						pObj.put(ChildToParentItemMap.get(cCol), (cObj != null ? Decimal.valueOf(String.valueOf(cObj.get(cCol))) : 0));
					}
					rtn.add(pObj);
				}
			}
			return rtn;
		}
	}
	
	
	
	/**
	* ユーティリティ：Set or List からカンマ区切りの文字列を生成する
	**/
	static String joinArray(Set<String> param, Boolean withQuote){
		String rtn = '';
		if(param == null){ return rtn; }
		for(String wk : param){ rtn += (withQuote ? ',\'' + wk + '\'' : ',' + wk); }
		return rtn.length() > 0 ? rtn.substring(1) : rtn;
	}
	static String joinArray(List<String> param, Boolean withQuote){
		String rtn = '';
		if(param == null){ return rtn; }
		for(String wk : param){ rtn += (withQuote ? ',\'' + wk + '\'' : ',' + wk); }
		return rtn.length() > 0 ? rtn.substring(1) : rtn;
	}
}