local count = 0

while true do 
  count = count + 1
  -- test break
  if count > 10 then break end
  -- test continue
  if count %2 ==0 then continue end
  print (count) 
end
