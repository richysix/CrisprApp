var success_classes = [ "PASSED_EMBRYO_SCREENING", "PASSED_SPERM_SCREENING",
  "SHIPPED", "SHIPPED_AND_IN_SYSTEM", "IN_SYSTEM", "CARRIERS", "F1_FROZEN"  ];

var failed_classes = [ "FAILED_EMBRYO_SCREENING", "FAILED_SPERM_SCREENING" ]

var info_classes = [ "DESIGNED", "ORDERED", "MADE", "INJECTED",
  "MISEQ_EMBRYO_SCREENING", "SPERM_FROZEN", "MISEQ_SPERM_SCREENING" ];

$(document).ready(function(){
  // set the css of statuses to info, success or danger
  // info
  for( i = 0; i < info_classes.length; i++ ){
    $("." + info_classes[i]).addClass( "info" );
  }
  // success
  for( i = 0; i < success_classes.length; i++ ){
    $("." + success_classes[i]).addClass( "success" );
  }
  // failure ones
  for( i = 0; i < failed_classes.length; i++ ){
    $("." + failed_classes[i]).addClass( "danger" );
  }

  $(".js-show-get-inj-form").click( function(){
    $("#add_inj_form").hide('fast');
    $("#get_inj_form").show('fast');
  } );
  
  $(".js-show-add-inj-form").click( function(){
    $("#get_inj_form").hide('fast');
    $("#add_inj_form").show('fast');
  } );
  
  $(".js-show-get-inj-form").click();
  
});
