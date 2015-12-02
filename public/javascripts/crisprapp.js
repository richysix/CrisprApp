var success_classes = [ "PASSED_EMBRYO_SCREENING", "PASSED_SPERM_SCREENING",
  "SHIPPED", "SHIPPED_AND_IN_SYSTEM", "IN_SYSTEM", "CARRIERS", "F1_FROZEN"  ];
var failed_classes = [ "FAILED_EMBRYO_SCREENING", "FAILED_SPERM_SCREENING" ]

$(document).ready(function(){
  // set the css of statuses to success or warning
  for( i = 0; i < success_classes.length; i++ ){
    $("." + success_classes[i]).addClass( "success" );
  }
  // failure ones
  for( i = 0; i < failed_classes.length; i++ ){
    $("." + failed_classes[i]).addClass( "danger" );
  }

});
