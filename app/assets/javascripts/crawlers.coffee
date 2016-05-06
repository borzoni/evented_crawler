# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
   
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]' 
getType =  (elem) -> 
  return Object.prototype.toString.call(elem).slice(8, -1)
isObject = (elem) -> 
  return getType(elem) == 'Object'

$(document).on 'ready', (e) -> 
    $('input[type="submit"]').on 'click', ->
      $('form.new_crawler, form.edit_crawler').data('button', this.name)
    
    $('form.new_crawler, form.edit_crawler').on 'submit', (e) -> 
       submitButton = $(this).data('button') || $('input[type="submit"]').get(0).name
       
       $(this).submit() if submitButton == 'save_crawler'
       if submitButton == 'test_url_page'
         url = $("#crawler_test_url1").val()
         s = window.location.pathname.split("/")[2]
         localStorage.setItem("testUrl1-#{s}",url);
         valuesToSubmit = $(this).serializeArray();
         newVals = valuesToSubmit.map (v) -> 
            return {"name": "_method", "value": "post"} if v.name == '_method'
            return v
              
         valuesToSubmit = $.param(newVals)       
         $.ajax({
          type: "POST",
          url: "/test_url",
          data: valuesToSubmit,
          dataType: "JSON",
          success: (json) ->
            html = ""
            if json.error
              html ="<p>#{json.error}</p>"
            else
              if json[0]
                html = html + "<div class='row'><div class='col-md-6'>Url is in black list</div></div>"
              if json[1]
                html = html + "<div class='row'><div class='col-md-6'>Url is an item card</div></div>"
              if !(json[0]) and !(json[1])  
                html = html + "<div class='row'><div class='col-md-6'>Url doesn't fit any pattern</div></div>"
            $("#filler_info_url").empty()    
            $("#filler_info_url").append(html)
         })
         return false    
       if submitButton == 'test_selectors'
         s = window.location.pathname.split("/")[2]
         url = $("#crawler_test_url2").val()
         localStorage.setItem("testUrl2-#{s}",url);
         valuesToSubmit = $(this).serializeArray();
         newVals = valuesToSubmit.map (v) -> 
            return {"name": "_method", "value": "post"} if v.name == '_method'
            return v
              
         valuesToSubmit = $.param(newVals)       
         $.ajax({
          type: "POST",
          url: "/test_selectors",
          data: valuesToSubmit,
          dataType: "JSON",
          success: (json) ->
            html = ""
            if json.error
              html ="<p>#{json.error}</p>"
            else
              for k,v of json
                if v
                  found_count = 1
                  if typeIsArray v
                    found_count = v.length
                  if isObject(v)
                    v = JSON.stringify(v)
                  found_text = "#{found_count} - #{v}"  
                  console.log()
                else
                  found_text = "Не найдено"  
                    
                html = html + "<div class='row'><div class='col-sm-2'>#{k}</div><div class='col-sm-10'>#{found_text}</div><hr></div>"
            
            $("#filler_info_selectors").empty()    
            $("#filler_info_selectors").append(html)
         })
         return false; 
  
    if $("#crawler_test_url2").length
      s = window.location.pathname.split("/")[2]
      url = localStorage.getItem("testUrl2-#{s}")
      if url
        $("#crawler_test_url2").val(url)
        click_btn = ()-> 
          $( "input#test_selectors" ).click()
        setTimeout(click_btn, 100)
      
    if $("#crawler_test_url1").length
      s = window.location.pathname.split("/")[2]
      url = localStorage.getItem("testUrl1-#{s}")
      if url
        $("#crawler_test_url1").val(url) 
        click_btn = ()-> 
          $("#test_url_page" ).click()
        setTimeout(click_btn, 100) 
      

