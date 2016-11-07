defmodule Weaver.BuilderTest do
  use ExUnit.Case, async: true

  defmodule Image do
    defstruct id: nil
  end

  defmodule ImageProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, %Image{id: id})
      end)
    end
  end

  defmodule Parent do
    defstruct id: nil, children: nil
  end

  defmodule Child do
    defstruct id: nil, parent_id: nil
  end

  defmodule ChildrenProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, [%Child{id: "#{id}_1", parent_id: id}, %Child{id: "#{id}_2", parent_id: id}])
      end)
    end
  end

  defmodule NilChildrenProvider do
    def find(_ids) do
      Map.new
    end
  end

  defmodule ParentWeaver do
    use Weaver.Builder
    weaver %{[:id] => [[:children]]}, provider: ChildrenProvider
  end

  defmodule NilParentWeaver do
    use Weaver.Builder
    weaver %{[:id] => [[:children]]}, provider: NilChildrenProvider
  end

  defmodule User do
    defstruct id: nil, avatar_id: nil, avatar: nil
  end

  defmodule ImageCollection do
    defstruct image_ids: [], images: []
  end

  defmodule UserProvider do
    def find(ids) do
      Enum.reduce(ids, Map.new, fn id, acc ->
        Map.put(acc, id, %User{id: id, avatar_id: "avatar_#{id}"})
      end)
    end
  end

  defmodule Post do
    defstruct id: nil, image_id: nil, image: nil, user_id: nil, user: nil, data: nil
  end

  defmodule OneWeftWeaver do
    use Weaver.Builder
    weaver %{:image_id => :image}, provider: ImageProvider
  end

  defmodule MultiWeftWeaver do
    use Weaver.Builder
    weaver %{:image_id => :image, [:user, :avatar_id] => [:user, :avatar]}, provider: ImageProvider
  end

  defmodule SimpleWeaver do
    def weave(items) do
      Enum.map(items, fn item ->
        Map.put(item, :data, Map.get(item, :id))
      end)
    end
  end

  defmodule MultiWeavers do
    use Weaver.Builder
    weaver %{:user_id => :user}, provider: UserProvider
    weaver %{:image_id => :image, [:user, :avatar_id] => [:user, :avatar]}, provider: ImageProvider
  end

  defmodule ImageCollectionWeaver do
    use Weaver.Builder
    weaver %{[[:image_ids]] => [[:images]]}, provider: ImageProvider
  end

  defmodule ComposeWeaver do
    use Weaver.Builder
    weaver SimpleWeaver
    weaver %{:image_id => :image}, provider: ImageProvider
  end

  defmodule ConvertIdsWeaver do
    use Weaver.Builder
    weaver %{:id => :image}, provider: ImageProvider, id_converter: :to_image_id

    def to_image_id(id) do
      "post_#{id}"
    end
  end

  test "wefts should raise exception for non-tailing array" do
    assert_raise RuntimeError, fn ->
      defmodule BadWeaver do
        use Weaver.Builder
        weaver %{[:a, [:b], :c] => :d}, provider: :not_exist
      end
    end
  end

  test "wefts should accepts tailing array" do
    defmodule ArrayWeaver do
      use Weaver.Builder
      weaver %{[:a, [:b]] => [[:c]]}, provider: :not_exist
    end
  end

  test "id_converter should be defined in the module" do
    assert_raise RuntimeError, fn ->
      defmodule BadIdConverter do
        use Weaver.Builder
        weaver %{:a => :b}, provider: :not_exist, id_converter: :not_defined
      end
    end
  end

  test "exception should be raised for empty weaver" do
    assert_raise RuntimeError, fn ->
      defmodule EmptyWeaver do
        use Weaver.Builder
      end
    end
  end

  test "should weave one weft" do
    assert(
      OneWeftWeaver.weave([%Post{image_id: 1}, %Post{image_id: 2}])
      == [%Post{image_id: 1, image: %Image{id: 1}}, %Post{image_id: 2, image: %Image{id: 2}}]
    )
  end

  test "should weave multi weft" do
    assert(
      MultiWeftWeaver.weave(
        [%Post{
          image_id: 1,
          user: %User{
            avatar_id: 10
          }
        }, %Post{
          image_id: 2,
          user: %User{
            avatar_id: 11
          }
        }]
      )
      ==
      [%Post{
        image_id: 1,
        image: %Image{id: 1},
        user: %User{
          avatar_id: 10,
          avatar: %Image{id: 10}
        }
      }, %Post{
        image_id: 2,
        image: %Image{id: 2},
        user: %User{
          avatar_id: 11,
          avatar: %Image{id: 11}
        }
      }]
    )
  end

  test "should weave mult provider" do
    assert(
      MultiWeavers.weave(
        [%Post{
          image_id: 1,
          user_id: 11
        }, %Post{
          image_id: 2,
          user_id: 12
        }]
      )
      ==
      [%Post{
        image_id: 1,
        user_id: 11,
        image: %Image{id: 1},
        user: %User{
          id: 11,
          avatar_id: "avatar_11",
          avatar: %Image{id: "avatar_11"}
        }
      }, %Post{
        image_id: 2,
        user_id: 12,
        image: %Image{id: 2},
        user: %User{
          id: 12,
          avatar_id: "avatar_12",
          avatar: %Image{id: "avatar_12"}
        }
      }]
    )
  end

  test "should weave list" do
    assert(
      ImageCollectionWeaver.weave([
        %ImageCollection{image_ids: [1, 2]},
        %ImageCollection{image_ids: [2, 3]}
      ])
    ==
    [%ImageCollection{
      image_ids: [1, 2],
      images: [%Image{id: 1}, %Image{id: 2}]
    }, %ImageCollection{
      image_ids: [2, 3],
      images: [%Image{id: 2}, %Image{id: 3}]
    }]
    )
  end

  test "should weave compose weaver" do
    assert(
      ComposeWeaver.weave([
        %Post{id: 1, image_id: 1},
        %Post{id: 2, image_id: 2}
      ])
      ==
      [
        %Post{id: 1, data: 1, image_id: 1, image: %Image{id: 1}},
        %Post{id: 2, data: 2, image_id: 2, image: %Image{id: 2}}
      ]
    )
  end

  test "should weave multi value" do
    assert(
      ParentWeaver.weave([
        %Parent{id: 1},
        %Parent{id: 2}
      ])
      ==
      [
        %Parent{id: 1, children: [%Child{id: "1_1", parent_id: 1}, %Child{id: "1_2", parent_id: 1}]},
        %Parent{id: 2, children: [%Child{id: "2_1", parent_id: 2}, %Child{id: "2_2", parent_id: 2}]}
      ]
    )
  end

  test "should assign empty array to array properties" do
    assert(
      NilParentWeaver.weave([
        %Parent{id: 1},
        %Parent{id: 2}
      ])
      ==
      [
        %Parent{id: 1, children: []},
        %Parent{id: 2, children: []}
      ]
    )
  end

  test "should convert ids before fetching items" do
    assert(
      ConvertIdsWeaver.weave([
        %Post{id: 1},
        %Post{id: 2}
      ])
      ==
      [
        %Post{id: 1, image: %Image{id: "post_1"}},
        %Post{id: 2, image: %Image{id: "post_2"}}
      ]
    )
  end
end
