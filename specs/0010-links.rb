
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql << <<-EOF

             link AS DEFAULT
          asker_id |  giver_id

         ----------------------
              screen_name
        id, owner_id, screen_name
         ----------------------

               ----------------------
                       block
                blocked  |  victim
             screen_name | screen_name
               ----------------------

                 # BLOCK_SCREEN_TYPE_ID
     # ( f.out = blocked AND f.in.owner_id = victim.owner_id )
                       # OR
     # ( f.in = blocked AND f.out.owner_id = victim.owner_id )
               # ----------------------
                  # BLOCK_OWNER_TYPE_ID
# ( f.out.owner_id = blocked.owner_id AND f.in.owner_id  = victim.owner_id )
                       # OR
# ( f.in.owner_id  = blocked.owner_id AND f.out.owner_id = victim.owner_id )
               # ----------------------

                     post
                pinner | pub
screen_name, computer  | screen_name
          ORDER BY created_at DESC


                follow
              fan  |  star
       screen_name | screen_name

                 feed
          FROM
            follow, post
          OF
            :audience_id
          GROUP BY follow.star
          SELECT
            follow.star_screen_name
            post.*
            max(post.computer_created_at)
    EOF

    actual = sql.to_sql(:feed)

    asql actual

    fail
    sql(actual).should == "a"
  end # === it

end # === describe "links DSL"

