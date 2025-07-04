"! @testing BDEF:ZRAP100_R_TravelTP_582
CLASS zrap100_tc_travel_eml_582 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA:
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment,
      begin_date           TYPE /dmo/begin_date,
      end_date             TYPE /dmo/end_date,
      agency_mock_data     TYPE STANDARD TABLE OF /dmo/agency,
      customer_mock_data   TYPE STANDARD TABLE OF /dmo/customer.

    CLASS-METHODS:
      class_setup,    " setup test double framework
      class_teardown. " stop test doubles
    METHODS:
      setup,          " reset test doubles
      teardown.       " rollback any changes

    METHODS:
      " CUT: create with action call and commit
      create_with_action FOR TESTING RAISING cx_static_check.

ENDCLASS.



CLASS zrap100_tc_travel_eml_582 IMPLEMENTATION.
  METHOD class_setup.
    " create the test doubles for the underlying CDS entities
    cds_test_environment = cl_cds_test_environment=>create_for_multiple_cds(
                      i_for_entities = VALUE #(
                        ( i_for_entity = 'ZRAP100_R_TravelTP_582' ) ) ).

    " create test doubles for additional used tables.
    sql_test_environment = cl_osql_test_environment=>create(
    i_dependency_list = VALUE #( ( '/DMO/AGENCY' )
                                 ( '/DMO/CUSTOMER' ) ) ).

    " prepare the test data
    begin_date = cl_abap_context_info=>get_system_date( ) + 10.
    end_date   = cl_abap_context_info=>get_system_date( ) + 30.

    agency_mock_data   = VALUE #( ( agency_id = '070041' name = 'Agency 070041' ) ).
    customer_mock_data = VALUE #( ( customer_id = '000093' last_name = 'Customer 000093' ) ).
  ENDMETHOD.

 METHOD class_teardown.
   " remove test doubles
   cds_test_environment->destroy(  ).
   sql_test_environment->destroy(  ).
 ENDMETHOD.

   METHOD create_with_action.
     " create a complete composition: Travel (root)
     MODIFY ENTITIES OF ZRAP100_R_TravelTP_582
      ENTITY Travel
      CREATE FIELDS ( AgencyID CustomerID BeginDate EndDate Description TotalPrice BookingFee CurrencyCode )
        WITH VALUE #( (  %cid = 'ROOT1'
                         AgencyID      = agency_mock_data[ 1 ]-agency_id
                         CustomerID    = customer_mock_data[ 1 ]-customer_id
                         BeginDate     = begin_date
                         EndDate       = end_date
                         Description   = 'TestTravel 1'
                         TotalPrice    = '1100'
                         BookingFee    = '20'
                         CurrencyCode  = 'EUR'
                      ) )

*        " execute action `acceptTravel`
        ENTITY Travel
          EXECUTE acceptTravel
            FROM VALUE #( ( %cid_ref = 'ROOT1' ) )

     " execute action `deductDiscount`
      ENTITY Travel
        EXECUTE deductDiscount
          FROM VALUE #( ( %cid_ref = 'ROOT1'
                          %param-discount_percent = '20' ) )   "=> 20%

      " result parameters
      MAPPED   DATA(mapped)
      FAILED   DATA(failed)
      REPORTED DATA(reported).

     " expect no failures and messages
     cl_abap_unit_assert=>assert_initial( msg = 'failed'   act = failed ).
     cl_abap_unit_assert=>assert_initial( msg = 'reported' act = reported ).

     " expect a newly created record in mapped tables
     cl_abap_unit_assert=>assert_not_initial( msg = 'mapped-travel'  act = mapped-travel ).

     " persist changes into the database (using the test doubles)
     COMMIT ENTITIES RESPONSES
       FAILED   DATA(commit_failed)
       REPORTED DATA(commit_reported).

     " no failures expected
     cl_abap_unit_assert=>assert_initial( msg = 'commit_failed'   act = commit_failed ).
     cl_abap_unit_assert=>assert_initial( msg = 'commit_reported' act = commit_reported ).

     " read the data from the persisted travel entity (using the test doubles)
     SELECT * FROM ZRAP100_R_TravelTP_582 INTO TABLE @DATA(lt_travel). "#EC CI_NOWHERE
     " assert the existence of the persisted travel entity
     cl_abap_unit_assert=>assert_not_initial( msg = 'travel from db' act = lt_travel ).
     " assert the generation of a travel ID (key) at creation
     cl_abap_unit_assert=>assert_not_initial( msg = 'travel-id' act = lt_travel[ 1 ]-TravelID ).
*     " assert that the action has changed the overall status
     cl_abap_unit_assert=>assert_equals( msg = 'overall status' exp = 'A' act = lt_travel[ 1 ]-OverallStatus ).
     " assert the discounted booking_fee
     cl_abap_unit_assert=>assert_equals( msg = 'discounted booking_fee' exp = '16' act = lt_travel[ 1 ]-BookingFee ).

   ENDMETHOD.

   METHOD setup.
     " clear the test doubles per test
     cds_test_environment->clear_doubles(  ).
     sql_test_environment->clear_doubles(  ).
     " insert test data into test doubles
     sql_test_environment->insert_test_data( agency_mock_data   ).
     sql_test_environment->insert_test_data( customer_mock_data ).
   ENDMETHOD.

 METHOD teardown.
   " clean up any involved entity
   ROLLBACK ENTITIES.
 ENDMETHOD.

ENDCLASS.
