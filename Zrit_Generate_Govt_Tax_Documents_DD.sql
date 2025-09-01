/*  
Exec Zrit_Generate_Govt_Tax_Documents_DD '23','CI2659260000377','RM_SI'  
*/  

CREATE    or alter         Proc Zrit_Generate_Govt_Tax_Documents_DD
(  
 @Ou   Int,  
 @TranNo  VarChar(20),  
 @TranType VarChar(20)   
)  
As   
Begin   
  
Set NoCount On   
  
 
  
Declare @appuser varchar(100)
select @appuser = api_base_url
from zrit_api_clr_url_master (Nolock)
where int_module='BE_USER'
and category='appuser'
and clr_enabled_flag='y'

  
 Declare @BaseUrl VarChar(500)  
 Declare @ClientId VarChar(40)  
 Declare @ClientSecret VarChar(500)  
 Declare @Result VarChar(4000)  
 Declare @PostData VarChar(Max)  
 Declare @einvoicesub_url varchar(150)  
 Declare @ewaybillbyirnsub_url varchar(150)  
 Declare @ewaybillsub_url varchar(150)  
 Declare @api_method varchar(100)  
 Declare @api_auth varchar(100)  
 DECLARE @customerGSTIN varchar(100) 
 DECLARE @customercode varchar(100)  
 

 select @customerGSTIN=Cust_GSTN,
 @customercode=Cust_Code
 from interfacedb..zrit_Rmcl_eInvoice_Cust_Dtls  CustMst (Nolock)
 where Cust_Code in (select supp_cust_code
 from  scmdb..tcal_tran_hdr (Nolock)  
 where tran_no=@TranNo
 and tran_ou=@Ou
 )
  
 select   
 @einvoicesub_url=api_sub_url  
 from   
 zrit_api_clr_url_master (Nolock)  
 where int_module='cleartax'  
 and category='Einvoice'  
 and clr_enabled_flag='Y'  
  
 select   
 @ewaybillbyirnsub_url=api_sub_url  
 from   
 zrit_api_clr_url_master (Nolock)  
 where int_module='cleartax'  
 and category='Ewaybill-by-irn'  
 and clr_enabled_flag='Y'  
  
 select   
 @ewaybillsub_url=api_sub_url  
 from   
 zrit_api_clr_url_master (Nolock)  
 where int_module='cleartax'  
 and category='Ewaybill-non-irn'  
 and clr_enabled_flag='Y'  
  
   
 select @BaseUrl = api_base_url  
 ,@ClientId    = username  
 ,@ClientSecret = pass_word  
 ,@api_method   =method  
 ,@api_auth    =auth  
 --select distinct *  
 from zrit_api_clr_url_master (Nolock)  
 where int_module='cleartax'  
 and clr_enabled_flag='Y'  
 and method  = 'POST'  




 
			
 declare @limit_value numeric(28,8),@intr_intra varchar(100)
,@tax_cat varchar(50),@Packslipvalue Numeric(28,8), @SONUMBER varchar(100) 
,@region_code nvarchar(20)



select @SONUMBER=psd_ordernumber
from scmdb..ps_pack_slip_dtl (Nolock)
where psd_pkslipno=@tranno
and psd_ou=@ou

 


 select @tax_cat = tax_category 
 ,@region_code=own_tax_region
 from scmdb..tcal_tax_hdr With(Nolock)
 where tran_type='SAL_NSO'
 and tax_type='GST'
 and tran_no=@SONUMBER
 and tran_ou=@ou

 
 if @tax_cat like '%local%'
 begin
 select @intr_intra=1
 end
 else if @tax_cat like '%inter%'
 begin
 select @intr_intra=2
 end

 select @limit_value=Limit_Value
 from (select distinct  Limit_Value from 
 Zrit_ZEWAYBILL_CONFIG (Nolock)
 where statecode='19') R

 

 select @limit_value=ISNULL(@limit_value,0)

 Declare @tax_incl_amt numeric(28,3)
 Select	@tax_incl_amt=tax_incl_amt
							From scmdb..tcal_tax_dtl  D(Nolock) 
							Join scmdb..tcal_tran_hdr    H(Nolock) 
							on  D.tran_no		        =   H.tran_no	
							and D.tran_ou		        =   H.tran_ou	
							and D.tran_type		        =   H.tran_type
							and D.tax_type              =   H.tax_type
							Where	D.tran_no				=		@TranNo		
							And		D.tran_ou				=		@Ou
							And		D.tran_type			=		@TranType

					   


 DECLARE @JsonTable TABLE (  
  Ou   Int,  
  TranNo  VarChar(20),  
  TranType VarChar(20),  
  Process  VarChar(20)   
 )   
  
  
 Insert   
 into @JsonTable  
 select @Ou, @TranNo, @TranType, ''  
  
     
 Set @PostData = (SELECT * FROM @JsonTable FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER)  
  
  
 IF  ISNULL(@customerGSTIN,'') NOT IN ('URP')
 BEGIN --gstin 
  
		If Exists	(	Select	'x' 
						From scmdb..tcal_tax_dtl  D(Nolock) 
				        Join scmdb..tcal_tran_hdr    H(Nolock) 
				        on  D.tran_no		        =   H.tran_no	
				        and D.tran_ou		 =  H.tran_ou	
				        and D.tran_type		        =   H.tran_type
				        and D.tax_type              =   H.tax_type
						Where	D.tran_no				=		@TranNo		
						And		D.tran_ou				=		@Ou
						And		D.tran_type			=		@TranType 
						And		D.tax_type			=		'GST'
						And		(D.corr_tax_amt >0.0 or H.assessee_type='SEZ'))
						begin--Einvoice Generation starts 
						
							If not Exists ( Select 'x'   
											From interfacedb.dbo.Zrit_mcl_etoken_dtl (Nolock)   
											Where tran_no    =  @TranNo    
											And  tran_ou    =  @Ou  
											And  tran_type   =  @TranType  
											And  Irn + SignedQRCode Is not  Null )  
							Begin --table check  
      
									Select  @Result = dbo.APICall(@BaseUrl + @einvoicesub_url,  --'clear/generate/eInvoice'  
											@api_method,   
											@PostData,  
											@api_auth,   
											@ClientId,  
											@ClientSecret)  
							

	
							If (isnull(@Result,'') <> '"Y"')  
							Begin   
								select @result=IIF(@result like '%remote%','Token/Cleartax Configuration Issue',@result)
								Raiserror(@Result,16,1)  
								Return   
							End    
							End --table check  
						 End --Einvoice Generation Ends  
     
	        

	if @TranType not in ('RM_CCA', 'RM_CDA' , 'RM_CCI' ,'RM_CDIN','RM_CMI','RM_CDI','PM_SDI','PM_SCI' )
	begin--trantype    
	--Condition Basis above 50000  
	--Eway-Bill Generation with irn STARTS  
		If  Exists ( Select 'x'  
						From dbo.Zrit_mcl_etoken_dtl (Nolock)   
						Where tran_no   =   @TranNo    
						And  tran_ou   =   @Ou  
						And  tran_type  =   @TranType  
						And  eWaybill_No  Is   Null  
						and Irn + SignedQRCode Is not  Null
	   
		)   
		Begin--table exists
		
		if exists(
		select '*' from scmdb..zrit_cust_lo_info_iedk(nolock)  where  zrit_cust_code = @customercode
        and zrit_invoicing_code='INV')
		begin
		select @customercode=@customercode
		end
		Else
		begin


			if not exists (
							select '*' from scmdb..so_order_hdr(nolock) inner join
							scmdb..cobi_item_dtl(nolock) on so_no = sohdr_order_no
							where  sohdr_sale_type_dflt in('TRADE','SERV')
							and  tran_no =@TranNo
							and  tran_ou =@ou
			)
			begin--trade exists  


				if convert(numeric(28,3),@tax_incl_amt) >= convert(numeric(28,3),@limit_value)
					begin --limilt exists
						Select  @Result = dbo.APICall(@BaseUrl + @ewaybillbyirnsub_url,--'clear/generate/eWaybill/ByIRN',  
								@api_method,   
								@PostData,  
								@api_auth,   
								@ClientId,  
								@ClientSecret)   
 
					if exists(    Select '*'
									From dbo.Zrit_mcl_etoken_dtl (Nolock)   
									Where tran_no   =   @TranNo    
									And  tran_ou   =   @Ou  
									And  tran_type  =   @TranType  
									And  eWaybill_No  Is   Null  
									and Irn + SignedQRCode Is not  Null
									and ErrorCode  in('4009','107107','107')
									
					)
					begin --irn exists
						select @Result ='"Y"'
					end --irn exists
  
					if exists(    Select '*'
									From dbo.Zrit_mcl_etoken_dtl (Nolock)   
									Where tran_no   =   @TranNo    
									And  tran_ou   =   @Ou  
									And  tran_type  =   @TranType  
									And  eWaybill_No  Is   Null  
									and Irn + SignedQRCode Is not  Null
									and ErrorMessage like '%The distance between the pincodes%and%is not available in the system, you need to pass the actual distance%'
					)
					begin --irn exists
						select @Result ='"Y"'
					end   --irn exists
  




					If (@Result <> '"Y"')  
					Begin --error exists  
						select @result=IIF(@result like '%remote%','Token/Cleartax Configuration Issue',@result)
						Raiserror(@Result,16,1)  
						Return   
					End   --error exists  
				End  --limilt exists  
			End --Eway-Bill Generation with IRN ends  --trade exists
	end    --- Pandi --table exists
	end --consoli
	end --trantype 

	if	Exists ( Select 'x' 
			From scmdb..tcal_tax_dtl  D(Nolock) 
			Join scmdb..tcal_tran_hdr    H(Nolock) 
			on  D.tran_no		        =   H.tran_no	
			and D.tran_ou		        =   H.tran_ou	
			and D.tran_type		        =   H.tran_type
			and D.tax_type              =   H.tax_type
			Where	D.tran_no				=		@TranNo		
			And		D.tran_ou				=		@Ou
			And		D.tran_type			=		@TranType 
			And		D.tax_type			=		'GST'
			--and     h.tax_incl_amt>= @limit_value/*code commented by krishnan*/
			and case when h.tax_incl_amt=0.00 then taxable_amt else h.tax_incl_amt end >= @limit_value /*code added by krishnan*/
			and		H.tran_type not in ('RM_CCA', 'RM_CDA' , 'RM_CCI' ,'RM_CDIN','RM_CMI','RM_CDI','PM_SDI','PM_SCI' )
			)   
	Begin --for no Tax Invoice Ewaybill Generation

	If not Exists ( Select 'x'   
					From interfacedb.dbo.Zrit_mcl_etoken_dtl (Nolock)   
					Where tran_no    =  @TranNo    
					And  tran_ou    =  @Ou  
					--and eWaybill_status<>'A' /*Code added by krishnan to handle error E-way bill retry*/
					And  tran_type   =  @TranType)  
	Begin
     
	if not exists (
					select '*' from scmdb..so_order_hdr(nolock) inner join
					scmdb..cobi_item_dtl(nolock) on so_no = sohdr_order_no
					where  sohdr_sale_type_dflt in('TRADE','SERV')
					and  tran_no =@TranNo
					and  tran_ou =@ou
				  )
	begin --trade
	
			Select  @Result = dbo.APICall(@BaseUrl + @ewaybillsub_url,--'clear/generate/eWaybill',  
					@api_method,   
					@PostData,  
					@api_auth,   
					@ClientId,  
					@ClientSecret) 

			
			If (@Result <> '"Y"')  
			Begin   
				select @result=IIF(@result like '%remote%','Token/Cleartax Configuration Issue',@result)
				Raiserror(@Result,16,1)  
				Return   
			End     
		End--trade
	End --for no Tax Invoice Ewaybill Generation
	End 




if @trantype in ('SAL_PS')
begin --Eway-Bill Generation starts without IRN starts   
    
if not exists (
			select '*' from scmdb..so_order_hdr(nolock) inner join
			scmdb..cobi_item_dtl(nolock) on so_no = sohdr_order_no
			where  sohdr_sale_type_dflt in('TRADE','SERV')
			and  tran_no =@TranNo
			and  tran_ou =@ou
			)
			begin--eway

			Select @Result = dbo.APICall(@BaseUrl + @ewaybillsub_url,--'clear/generate/eWaybill',  
					@api_method,   
					@PostData,  
					@api_auth,   
					@ClientId,  
					@ClientSecret)   
  
		   If (@Result <> '"Y"')  
			Begin   
				 select @result=IIF(@result like '%remote%','Token/Cleartax Configuration Issue',@result)+ErrorMessage
				 from dbo.Zrit_mcl_etoken_dtl A(Nolock)   
				 where  A.tran_no=@TranNo--'RJT23/COB0000013'  
				 and    A.tran_ou=@ou  
				 Raiserror(@Result,16,1)  
				 Return   
			End 
		End--eway
	End

  End  

  /*Code commented by  krishnan start*/
  /*
      Update A  
      set InvRefNum     =case when Irn ='NA'  then null else Irn  end 
      ,eway_bill_no     =eWaybill_No  
      ,eway_bill_date   =eWaybill_Date  
      ,einv_Qrcode   =SignedQRCode  
      ,einv_status   =case when eInvoice_status='NA'  then null else eInvoice_status end
      ,einv_signinv   =SignedInvoice  
      ,ewb_status    =eWaybill_status  
      ,einv_ackdt       =ackdt  
      ,einv_ackno    =ackno  
      ,errorcode    =B.ErrorCode  
      ,errordescription =SUBSTRING(ErrorMessage, 1, 255)  
      from  scmdb..tcal_tran_hdr   A  
      Join dbo.Zrit_mcl_etoken_dtl B(Nolock)   
      on  A.tran_no=B.tran_no  
      and A.tran_ou=B.tran_ou  
      and tax_type='GST'  
      where A.tran_no=@TranNo--'RJT23/COB0000013'  
      and A.tran_ou=@ou  
      and A.tax_type='GST'  
  
*/

/*Code commented by  krishnan end*/

/*Code added by  krishnan start*/
 
if exists(
  select '*'
  from dbo.Zrit_mcl_etoken_dtl A(nolock)
						where A.tran_no=@TranNo
						and A.tran_ou=@ou
						and eInvoice_status='N'
						and eWaybill_status='A'
)

begin



      Update A  
      set InvRefNum     =case when Irn ='NA'  then null else Irn  end 
      ,eway_bill_no     =eWaybill_No  
      ,eway_bill_date   =eWaybill_Date  
      ,einv_Qrcode   =SignedQRCode  
      ,einv_status   =case when eInvoice_status='NA'  then null else eInvoice_status end
      ,einv_signinv   =SignedInvoice  
      ,ewb_status    =eWaybill_status  
      ,einv_ackdt       =ackdt  
      ,einv_ackno    =ackno  
      ,errorcode    =B.ErrorCode  
      ,errordescription =SUBSTRING(ErrorMessage, 1, 255)  
      from  scmdb..tcal_tran_hdr   A  
      Join dbo.Zrit_mcl_etoken_dtl B(Nolock)   
      on  A.tran_no=B.tran_no  
      and A.tran_ou=B.tran_ou  
      and tax_type='GST'  
      where A.tran_no=@TranNo--'RJT23/COB0000013'  
      and A.tran_ou=@ou  
      and A.tax_type='GST'  

end 




if exists(
  select '*'
  from dbo.Zrit_mcl_etoken_dtl A(nolock)
						where A.tran_no=@TranNo
						and A.tran_ou=@ou
						and eInvoice_status='A'
						and eWaybill_status='A'
)

begin


      Update A  
      set InvRefNum     =case when Irn ='NA'  then null else Irn  end 
      ,eway_bill_no     =eWaybill_No  
      ,eway_bill_date   =eWaybill_Date  
      ,einv_Qrcode   =SignedQRCode  
      ,einv_status   =case when eInvoice_status='NA'  then null else eInvoice_status end
      ,einv_signinv   =SignedInvoice  
      ,ewb_status    =eWaybill_status  
      ,einv_ackdt       =ackdt  
      ,einv_ackno    =ackno  
      ,errorcode    =B.ErrorCode  
      ,errordescription =SUBSTRING(ErrorMessage, 1, 255)  
      from  scmdb..tcal_tran_hdr   A  
      Join dbo.Zrit_mcl_etoken_dtl B(Nolock)   
      on  A.tran_no=B.tran_no  
      and A.tran_ou=B.tran_ou  
      and tax_type='GST'  
      where A.tran_no=@TranNo--'RJT23/COB0000013'  
      and A.tran_ou=@ou  
      and A.tax_type='GST'  

end 

/*Code added by  krishnan end*/
  ---Manual update for error which were not updated via API
						update A
						set
						 ErrorCode	 =''
						,ErrorMessage=''
						from dbo.Zrit_mcl_etoken_dtl A
						where A.tran_no=@TranNo--'RJT23/COB0000013'
						and A.tran_ou=@ou
						and a.tran_no!='AT2630260000002'
						and (
						(eInvoice_status='A' and isnull(Irn,'')<>'')
						or
						(eWaybill_status='A' and isnull(eWaybill_No,'')<>'')
						)

						/*Code commented by  krishnan start*/
/*						update A
						set errorcode	  = B.ErrorCode
						,errordescription = SUBSTRING(ErrorMessage, 1, 255)
						from  scmdb..tcal_tran_hdr   A
						Join dbo.Zrit_mcl_etoken_dtl B(Nolock) 
						on  A.tran_no=B.tran_no
						and A.tran_ou=B.tran_ou
						and tax_type='GST'
						where A.tran_no=@TranNo--'RJT23/COB0000013'
						and A.tran_ou=@ou
						and A.tax_type='GST'
						and a.tran_no!='AT2630260000002'
   */
   /*Code commented by  krishnan end*/
End 



